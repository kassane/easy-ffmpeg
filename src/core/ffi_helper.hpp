// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Matheus C. Franca

#pragma once
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <string>
#include <string_view>
#include <vector>
#if __has_include(<filesystem>)
#include <filesystem>
namespace fs = std::filesystem;
#endif
#if __has_include(<charconv>)
#include <charconv>
#endif
#ifdef _WIN32
#include <io.h>
#include <process.h>
#define popen _popen
#define pclose _pclose
#else
#include <sys/stat.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <unistd.h>
#endif

namespace process {
inline std::vector<std::string> tokenize(std::string_view cmd) {
  std::vector<std::string> toks;
  std::string cur;
  bool in_quote = false;
  for (size_t i = 0; i < cmd.size(); i++) {
    char c = cmd[i];
    if (in_quote) {
      if (c == '\\' && i + 1 < cmd.size()) {
        cur += cmd[++i];
      } else if (c == '"') {
        in_quote = false;
      } else {
        cur += c;
      }
    } else {
      if (c == '"') {
        in_quote = true;
      } else if (c == ' ' || c == '\t') {
        if (!cur.empty()) {
          toks.push_back(cur);
          cur.clear();
        }
      } else {
        cur += c;
      }
    }
  }
  if (!cur.empty()) toks.push_back(cur);
  return toks;
}

inline std::vector<const char*> to_argv(const std::vector<std::string>& toks) {
  std::vector<const char*> argv(toks.size() + 1);
  for (size_t i = 0; i < toks.size(); i++) argv[i] = toks[i].c_str();
  argv[toks.size()] = nullptr;
  return argv;
}

// Safe exec: fork+execvp on POSIX, _spawnvp on Windows.
[[nodiscard]] inline int run_str(std::string_view cmd) {
  auto toks = tokenize(cmd);
  if (toks.empty()) return -1;
  auto argv = to_argv(toks);
#ifdef _WIN32
  // Windows: _spawnvp blocks until child exits (same semantics as waitpid)
  intptr_t rc =
      _spawnvp(_P_WAIT, argv[0], const_cast<char* const*>(argv.data()));
  return (rc < 0) ? -1 : (int)rc;
#else
  pid_t pid = fork();
  if (pid < 0) return -1;
  if (pid == 0) {
    execvp(argv[0], const_cast<char* const*>(argv.data()));
    _exit(127);
  }
  int status;
  waitpid(pid, &status, 0);
  if (WIFEXITED(status)) return WEXITSTATUS(status);
  return -1;
#endif
}

[[nodiscard]] inline bool exists(std::string_view path) {
#if __has_include(<filesystem>)
  std::error_code ec;
  return fs::exists(path, ec);
#else
  struct stat st;
  return (stat(std::string(path).c_str(), &st) == 0);
#endif
}

// Validate path: reject .. traversal and special files (devices, symlinks,
// FIFOs). Returns 0 if valid, 1 if path contains "..", 2 if not a regular file.
[[nodiscard]] inline int validate_path(std::string_view path) {
  std::string p(path);
  if (p.find("..") != std::string::npos) return 1;
  // Reject injection characters used in concat lists and ffmpeg filters
  for (char c : p) {
    if (c == '\'' || c == '\n' || c == '\r' || c == '\0') return 1;
  }
#if __has_include(<filesystem>)
  std::error_code ec;
  if (!fs::exists(p, ec)) return 2;
  if (!fs::is_regular_file(p, ec)) return 2;
#else
  struct stat st;
  if (stat(p.c_str(), &st) != 0) return 2;
  if (!S_ISREG(st.st_mode)) return 2;
#endif
  return 0;
}

// Run command and capture stdout. Safe: fork+execvp (POSIX), _popen (Windows).
[[nodiscard]] inline std::string run_capture(std::string_view cmd) {
#ifdef _WIN32
  FILE* p = _popen(std::string(cmd).c_str(), "r");
  if (!p) return "";
  std::string result;
  char buf[512];
  while (fgets(buf, sizeof(buf), p)) result += buf;
  _pclose(p);
  return result;
#else
  int pipefd[2];
  if (pipe(pipefd) < 0) return "";
  auto toks = tokenize(cmd);
  if (toks.empty()) {
    close(pipefd[0]);
    close(pipefd[1]);
    return "";
  }
  auto argv = to_argv(toks);
  pid_t pid = fork();
  if (pid < 0) {
    close(pipefd[0]);
    close(pipefd[1]);
    return "";
  }
  if (pid == 0) {
    close(pipefd[0]);
    dup2(pipefd[1], STDOUT_FILENO);
    close(pipefd[1]);
    execvp(argv[0], const_cast<char* const*>(argv.data()));
    _exit(127);
  }
  close(pipefd[1]);
  std::string result;
  char buf[512];
  ssize_t n;
  while ((n = read(pipefd[0], buf, sizeof(buf) - 1)) > 0) {
    buf[n] = 0;
    result += buf;
  }
  close(pipefd[0]);
  int status;
  waitpid(pid, &status, 0);
  return result;
#endif
}

// Like run_capture but also captures stderr (redirects to stdout via pipe).
[[nodiscard]] inline std::string run_capture_stderr(std::string_view cmd) {
#ifdef _WIN32
  FILE* p = _popen(std::string(cmd).c_str(), "r");
  if (!p) return "";
  std::string result;
  char buf[512];
  while (fgets(buf, sizeof(buf), p)) result += buf;
  _pclose(p);
  return result;
#else
  int pipefd[2];
  if (pipe(pipefd) < 0) return "";
  auto toks = tokenize(cmd);
  if (toks.empty()) {
    close(pipefd[0]);
    close(pipefd[1]);
    return "";
  }
  auto argv = to_argv(toks);
  pid_t pid = fork();
  if (pid < 0) {
    close(pipefd[0]);
    close(pipefd[1]);
    return "";
  }
  if (pid == 0) {
    close(pipefd[0]);
    dup2(pipefd[1], STDOUT_FILENO);
    dup2(pipefd[1], STDERR_FILENO);
    close(pipefd[1]);
    execvp(argv[0], const_cast<char* const*>(argv.data()));
    _exit(127);
  }
  close(pipefd[1]);
  std::string result;
  char buf[512];
  ssize_t n;
  while ((n = read(pipefd[0], buf, sizeof(buf) - 1)) > 0) {
    buf[n] = 0;
    result += buf;
  }
  close(pipefd[0]);
  int status;
  waitpid(pid, &status, 0);
  return result;
#endif
}
}  // namespace process

namespace cli {
inline int g_argc = 0;
inline char** g_argv = nullptr;
inline std::vector<std::string> g_storage;
inline std::vector<char*> g_ptrs;
inline void capture() {
  g_storage.clear();
#ifdef _WIN32
  // Windows: parse command line string
  char* cmdline = GetCommandLineA();
  if (!cmdline) return;
  bool in_quote = false;
  std::string cur;
  for (char* p = cmdline; *p; p++) {
    if (*p == '"') {
      in_quote = !in_quote;
      continue;
    }
    if ((*p == ' ' || *p == '\t') && !in_quote) {
      if (!cur.empty()) {
        g_storage.push_back(cur);
        cur.clear();
      }
    } else {
      cur += *p;
    }
  }
  if (!cur.empty()) g_storage.push_back(cur);
#else
  // POSIX: read /proc/self/cmdline
  FILE* f = fopen("/proc/self/cmdline", "rb");
  if (!f) return;
  char buf[4096];
  size_t n = fread(buf, 1, sizeof(buf) - 1, f);
  fclose(f);
  buf[n] = 0;
  size_t start = 0;
  for (size_t i = 0; i <= n; i++) {
    if (i == n || buf[i] == 0) {
      if (i > start) g_storage.push_back(std::string(buf + start, i - start));
      start = i + 1;
    }
  }
#endif
  g_argc = (int)g_storage.size();
  g_ptrs.clear();
  for (auto& s : g_storage) g_ptrs.push_back(&s[0]);
  g_argv = g_ptrs.data();
}
inline int argc() { return g_argc; }
inline int arg_matches(int pos, std::string_view val) {
  if (pos >= g_argc) return 0;
  return (std::string_view(g_argv[pos]) == val) ? 1 : 0;
}
inline int has_help() {
  for (int i = 1; i < g_argc; i++)
    if (std::string_view(g_argv[i]) == "--help" ||
        std::string_view(g_argv[i]) == "-h")
      return 1;
  return 0;
}
inline int has_flag(std::string_view f) {
  for (int i = 1; i < g_argc; i++)
    if (std::string_view(g_argv[i]) == f) return 1;
  return 0;
}
inline std::string get_flag_value(std::string_view flag) {
  for (int i = 1; i < g_argc - 1; i++)
    if (std::string_view(g_argv[i]) == flag) return std::string(g_argv[i + 1]);
  return "";
}
inline std::string get_positional(int n) {
  int count = 0;
  for (int i = 2; i < g_argc; i++) {
    if (g_argv[i][0] == '-') continue;
    if (count == n) return std::string(g_argv[i]);
    count++;
  }
  return "";
}
inline int positional_count() {
  int count = 0;
  for (int i = 2; i < g_argc; i++)
    if (g_argv[i][0] != '-') count++;
  return count;
}
inline int is_dry_run() {
  for (int i = 1; i < g_argc; i++)
    if (std::string_view(g_argv[i]) == "--dry-run") return 1;
  return 0;
}
}  // namespace cli

// === Build checks (pure C++17, no shell/grep) ===
namespace build {
// Read all lines from a .carbon file, skipping Constants.carbon.
// Returns lines as vector of (filename:linenum:content).
inline std::vector<std::string> read_carbon_src() {
  std::vector<std::string> lines;
#if __has_include(<filesystem>)
  for (auto& entry : fs::recursive_directory_iterator("src")) {
    if (!entry.is_regular_file()) continue;
    auto ext = entry.path().extension().string();
    if (ext != ".carbon") continue;
    if (entry.path().filename() == "Constants.carbon") continue;
    FILE* f = fopen(entry.path().c_str(), "r");
    if (!f) continue;
    char buf[4096];
    int lineno = 0;
    while (fgets(buf, sizeof(buf), f)) {
      lineno++;
      std::string line(buf);
      // strip trailing newline
      while (!line.empty() && (line.back() == '\n' || line.back() == '\r'))
        line.pop_back();
      lines.push_back(entry.path().string() + ":" + std::to_string(lineno) +
                      ":" + line);
    }
    fclose(f);
  }
#endif
  return lines;
}

[[nodiscard]] inline int check_no_magic() {
  auto lines = read_carbon_src();
  std::vector<std::string> hits;
  // Magic string literals that must only appear in Constants.carbon
  const char* magic_strs[] = {"\"-c:v\"", "\"-b:v\"", "\"-ss\"", "\"-t\"",
                              "\"h264\"", "\"aac\"",  "\"mp4\"", "\"libx264\""};
  // Magic integer literals that must only appear in Constants.carbon
  const char* magic_nums[] = {"23", "1280", "720", "192000", "2500", "64"};
  for (auto& line : lines) {
    // Extract the source content (after third colon)
    size_t c1 = line.find(':');
    if (c1 == std::string::npos) continue;
    size_t c2 = line.find(':', c1 + 1);
    if (c2 == std::string::npos) continue;
    std::string content = line.substr(c2 + 1);
    // Skip comment lines
    size_t first_non_space = content.find_first_not_of(" \t");
    if (first_non_space != std::string::npos &&
        content.substr(first_non_space, 2) == "//")
      continue;
    // Skip help string lines
    if (content.find("Core.PrintStr") != std::string::npos) continue;
    // Check magic strings
    for (auto* pat : magic_strs) {
      if (content.find(pat) != std::string::npos) {
        hits.push_back(line + "\n");
        goto next_line;
      }
    }
    // Skip build/compiler flags (e.g. -std=c++23)
    if (content.find("-std=") != std::string::npos ||
        content.find("-I") != std::string::npos ||
        content.find("-L") != std::string::npos ||
        content.find("-l") != std::string::npos) {
      goto next_line;
    }
    // Check magic numbers (word-bounded)
    for (auto* num : magic_nums) {
      size_t pos = 0;
      while ((pos = content.find(num, pos)) != std::string::npos) {
        // Check word boundaries (reject letters, digits, underscores — like
        // grep's [^A-Za-z_])
        auto is_id_char = [](char c) -> bool {
          return (c >= '0' && c <= '9') || (c >= 'A' && c <= 'Z') ||
                 (c >= 'a' && c <= 'z') || c == '_';
        };
        bool left_ok = (pos == 0) || !is_id_char(content[pos - 1]);
        size_t end = pos + strlen(num);
        bool right_ok = (end >= content.size()) || !is_id_char(content[end]);
        if (left_ok && right_ok) {
          hits.push_back(line + "\n");
          goto next_line;
        }
        pos += strlen(num);
      }
    }
  next_line:;
  }
  if (!hits.empty()) {
    fprintf(stderr, "Magic literal(s) outside src/core/Constants.carbon:\n");
    for (auto& h : hits) fprintf(stderr, "%s", h.c_str());
    return 1;
  }
  printf("[check-no-magic] clean\n");
  return 0;
}

[[nodiscard]] inline int check_no_duplication() {
  auto lines = read_carbon_src();
  int errors = 0;
  auto count_occurrences = [&](const char* pat) -> int {
    int n = 0;
    for (auto& line : lines) {
      size_t c1 = line.find(':');
      if (c1 == std::string::npos) continue;
      size_t c2 = line.find(':', c1 + 1);
      if (c2 == std::string::npos) continue;
      std::string content = line.substr(c2 + 1);
      if (content.find(pat) != std::string::npos) n++;
    }
    return n;
  };
  if (count_occurrences("fn Exec(") > 1) {
    fprintf(stderr, "Duplication: multiple fn Exec\n");
    errors = 1;
  }
  if (count_occurrences("fn AddFlagValue") > 1) {
    fprintf(stderr, "Duplication: multiple fn AddFlagValue\n");
    errors = 1;
  }
  if (!errors) printf("[check-no-duplication] clean\n");
  return errors;
}
}  // namespace build

// === FFI functions called from Carbon ===
inline void print_str(std::string_view s) {
  printf("%.*s", (int)s.size(), s.data());
}
inline void cli_exit(int code) {
  std::fflush(stdout);
  std::exit(code);
}

// === Argv builder ===
inline std::vector<std::string> g_tokens;
inline void argv_clear() { g_tokens.clear(); }
inline void argv_add_token(std::string_view t) {
  g_tokens.push_back(std::string(t));
}
inline std::string argv_build_cmd() {
  std::string r;
  size_t total = 0;
  for (auto& t : g_tokens) total += t.size() + 1;
  r.reserve(total);
  for (size_t i = 0; i < g_tokens.size(); i++) {
    if (i) r += " ";
    bool need_quote = g_tokens[i].find(' ') != std::string::npos ||
                      g_tokens[i].find('"') != std::string::npos;
    if (need_quote) {
      r += '"';
      for (char c : g_tokens[i]) {
        if (c == '"') r += '\\';
        r += c;
      }
      r += '"';
    } else {
      r += g_tokens[i];
    }
  }
  return r;
}

// === String helpers ===
namespace strh {
inline std::string make(std::string_view s) { return std::string(s); }
inline std::string concat3(std::string_view a, std::string_view b,
                           std::string_view c) {
  return std::string(a) + std::string(b) + std::string(c);
}
}  // namespace strh

// === String comparison helpers (Carbon nightly can't lower operator== for
// std::string) ===
inline bool str_eq(std::string_view a, std::string_view b) { return a == b; }
inline bool str_ne(std::string_view a, std::string_view b) { return a != b; }
inline std::string i_to_str(int i) { return std::to_string(i); }

// === Escape text for ffmpeg drawtext filter ===
inline std::string escape_drawtext(std::string_view text) {
  std::string result;
  result.reserve(text.size() * 2);
  for (char c : text) {
    if (c == ':' || c == '\'' || c == '\\' || c == ';' || c == '%' ||
        c == '[' || c == ']')
      result += '\\';
    result += c;
  }
  return result;
}

// === Scale height mapper ===
[[nodiscard]] inline std::string scale_height(std::string_view preset) {
  if (preset == "hd") return "720";
  if (preset == "fullhd") return "1080";
  if (preset == "2k") return "1440";
  if (preset == "retro") return "480";
  if (preset == "icon") return "240";
  return "0";
}

// Probe a single stream's codec name.
[[nodiscard]] inline std::string probe_stream_codec(std::string_view ffprobe,
                                                    std::string_view input,
                                                    std::string_view stream) {
  std::string cmd = std::string(ffprobe) + " -v quiet -select_streams " +
                    std::string(stream) +
                    " -show_entries stream=codec_name -of csv=p=0 " +
                    std::string(input);
  std::string raw = process::run_capture(cmd);
  while (!raw.empty() && (raw.back() == '\n' || raw.back() == '\r'))
    raw.pop_back();
  return raw;
}

// === Probe codecs ===
[[nodiscard]] inline std::string probe_codecs(std::string ffprobe,
                                              std::string input) {
  return probe_stream_codec(ffprobe, input, "v:0") + "," +
         probe_stream_codec(ffprobe, input, "a:0");
}

// === Path helpers ===
[[nodiscard]] inline std::string find_in_path(std::string_view name) {
  const char* path_env = std::getenv("PATH");
  if (!path_env) return "";
  std::string paths(path_env);
#ifdef _WIN32
  const char sep = ';';
#else
  const char sep = ':';
#endif
  size_t start = 0;
  while (start < paths.size()) {
    size_t pos = paths.find(sep, start);
    std::string dir = (pos != std::string::npos)
                          ? paths.substr(start, pos - start)
                          : paths.substr(start);
    std::string full = dir + "/" + std::string(name);
    if (access(full.c_str(), X_OK) == 0) return full;
    if (pos != std::string::npos)
      start = pos + 1;
    else
      break;
  }
  return "";
}

// === Cwd + Run ===
inline std::string cwd() {
#if __has_include(<filesystem>)
  std::error_code ec;
  auto p = fs::current_path(ec);
  return ec ? "." : p.string();
#else
  char buf[1024];
  if (getcwd(buf, sizeof(buf))) return std::string(buf);
  return ".";
#endif
}

// Quote a single argument for shell execution
inline std::string shell_quote(std::string_view arg) {
  bool need_quote = arg.find(' ') != std::string::npos ||
                    arg.find('"') != std::string::npos ||
                    arg.find('\'') != std::string::npos ||
                    arg.find('\\') != std::string::npos;
  if (!need_quote) return std::string(arg);
  std::string result = "\"";
  for (char c : arg) {
    if (c == '"' || c == '\\') result += '\\';
    result += c;
  }
  result += '"';
  return result;
}

// Template: works with any container of string-like types (vector, array,
// initializer_list). Properly quotes each argument.
template <typename Container>
[[nodiscard]] inline int run_shell(std::string_view app,
                                   const Container& args) {
  std::string cmd(app);
  for (const auto& arg : args) {
    cmd += " ";
    cmd += shell_quote(std::string_view(arg));
  }
  return std::system(cmd.c_str());
}

// Execute accumulated tokens via shell (C++ FFI — uses g_tokens vector
// directly)
[[nodiscard]] inline int argv_run_shell() {
  if (g_tokens.empty()) return -1;
  return run_shell(g_tokens[0], std::vector<std::string>(g_tokens.begin() + 1,
                                                         g_tokens.end()));
}

// Execute accumulated tokens via fork+execvp (no shell, no serialize
// round-trip)
[[nodiscard]] inline int argv_run_exec() {
  if (g_tokens.empty()) return -1;
  auto argv = process::to_argv(g_tokens);
#ifdef _WIN32
  intptr_t rc =
      _spawnvp(_P_WAIT, argv[0], const_cast<char* const*>(argv.data()));
  return (rc < 0) ? -1 : (int)rc;
#else
  pid_t pid = fork();
  if (pid < 0) return -1;
  if (pid == 0) {
    execvp(argv[0], const_cast<char* const*>(argv.data()));
    _exit(127);
  }
  int status;
  waitpid(pid, &status, 0);
  return WIFEXITED(status) ? WEXITSTATUS(status) : -1;
#endif
}

// Run command and show progress bar by parsing ffmpeg stderr.
// total_ms: total duration in milliseconds (-1 to skip percentage).
[[nodiscard]] inline int run_progress(std::string_view cmd, long total_ms) {
#ifdef _WIN32
  // Windows: _popen goes through cmd.exe (minimal risk for progress display)
  std::string full = std::string(cmd) + " 2>&1";
  FILE* p = _popen(full.c_str(), "r");
  if (!p) return -1;
  char buf[1024];
  while (fgets(buf, sizeof(buf), p)) {
    std::string line(buf);
    size_t pos = line.find("out_time_ms=");
    if (pos != std::string::npos) {
      long ms = std::stol(line.substr(pos + 12));
      if (total_ms > 0) {
        int pct = (int)((ms * 100) / total_ms);
        if (pct > 100) pct = 100;
        fprintf(stderr, "\r[%-50s] %d%%", std::string(pct / 2, '#').c_str(),
                pct);
      } else {
        int sec = (int)(ms / 1000);
        fprintf(stderr, "\r[%ds]", sec);
      }
    }
  }
  int rc = _pclose(p);
  if (total_ms > 0)
    fprintf(stderr, "\r[%-50s] 100%%\n", std::string(50, '#').c_str());
  else
    fprintf(stderr, "\n");
  return rc;
#else
  // POSIX: fork+execvp with pipe for safe progress parsing
  int pipefd[2];
  if (pipe(pipefd) < 0) return process::run_str(cmd);
  auto toks = process::tokenize(cmd);
  if (toks.empty()) {
    close(pipefd[0]);
    close(pipefd[1]);
    return -1;
  }
  auto argv = process::to_argv(toks);
  pid_t pid = fork();
  if (pid < 0) {
    close(pipefd[0]);
    close(pipefd[1]);
    return process::run_str(cmd);
  }
  if (pid == 0) {
    close(pipefd[0]);
    dup2(pipefd[1], STDOUT_FILENO);
    dup2(pipefd[1], STDERR_FILENO);
    close(pipefd[1]);
    execvp(argv[0], const_cast<char* const*>(argv.data()));
    _exit(127);
  }
  close(pipefd[1]);
  FILE* p = fdopen(pipefd[0], "r");
  if (!p) {
    waitpid(pid, nullptr, 0);
    return -1;
  }
  char buf[1024];
  while (fgets(buf, sizeof(buf), p)) {
    std::string line(buf);
    size_t pos = line.find("out_time_ms=");
    if (pos != std::string::npos) {
      long ms = std::stol(line.substr(pos + 12));
      if (total_ms > 0) {
        int pct = (int)((ms * 100) / total_ms);
        if (pct > 100) pct = 100;
        fprintf(stderr, "\r[%-50s] %d%%", std::string(pct / 2, '#').c_str(),
                pct);
      } else {
        int sec = (int)(ms / 1000);
        fprintf(stderr, "\r[%ds]", sec);
      }
    }
  }
  fclose(p);
  int status;
  waitpid(pid, &status, 0);
  if (total_ms > 0)
    fprintf(stderr, "\r[%-50s] 100%%\n", std::string(50, '#').c_str());
  else
    fprintf(stderr, "\n");
  if (WIFEXITED(status)) return WEXITSTATUS(status);
  return -1;
#endif
}

// Get duration in milliseconds via ffprobe. Returns -1 on error.
[[nodiscard]] inline long probe_duration_ms(std::string ffprobe,
                                            std::string input) {
  std::string safe_input = std::string(input);
  std::string cmd = std::string(ffprobe) +
                    " -v quiet -show_entries format=duration -of csv=p=0 " +
                    safe_input;
  std::string raw = process::run_capture(cmd);
  if (raw.empty()) return -1;
  while (!raw.empty() && (raw.back() == '\n' || raw.back() == '\r'))
    raw.pop_back();
#if __has_include(<charconv>)
  double val = 0;
  auto [ptr, ec] = std::from_chars(raw.data(), raw.data() + raw.size(), val);
  if (ec == std::errc()) return (long)(val * 1000);
#else
  try {
    return (long)(std::stod(raw) * 1000);
  } catch (...) {
  }
#endif
  return -1;
}

// Resolve carbon binary: PATH first, then vendored toolchain.
[[nodiscard]] inline std::string resolve_carbon() {
  std::string from_path = find_in_path("carbon");
  if (!from_path.empty()) return from_path;
  return cwd() + "/carbon_toolchain-0.0.0-0.nightly.2026.09.01/bin/carbon";
}

// === String-to-int conversion (Carbon has no stoi) ===
[[nodiscard]] inline int stoi(std::string s) noexcept {
#if __has_include(<charconv>)
  int val = 0;
  auto [ptr, ec] = std::from_chars(s.data(), s.data() + s.size(), val);
  return (ec == std::errc()) ? val : 0;
#else
  try {
    return std::stoi(s);
  } catch (...) {
    return 0;
  }
#endif
}

// === Validate string is numeric (digits, optional dot, optional leading -) ===
[[nodiscard]] constexpr int validate_numeric(std::string_view s) {
  if (s.empty()) return 0;
  size_t start = 0;
  if (s[0] == '-' || s[0] == '+') start = 1;
  if (start >= s.size()) return 0;
  int dots = 0;
  for (size_t i = start; i < s.size(); i++) {
    if (s[i] == '.') {
      dots++;
      if (dots > 1) return 0;
    } else if (s[i] < '0' || s[i] > '9')
      return 0;
  }
  return 1;
}

// Escape a single-quote in concat file list entries.
inline std::string escape_concat_entry(std::string_view s) {
  std::string r;
  r.reserve(s.size() + 4);
  for (char c : s) {
    if (c == '\'')
      r += "'\\''";
    else
      r += c;
  }
  return r;
}

// === Concat file list builder (2 files) ===
inline std::string build_concat_list_2(std::string_view a, std::string_view b) {
  return "file '" + escape_concat_entry(a) + "'\nfile '" +
         escape_concat_entry(b) + "'\n";
}

// === Concat file list builder (vector) ===
inline std::string build_concat_list(const std::vector<std::string>& files) {
  std::string list;
  list.reserve(files.size() * 30);
  for (const auto& f : files) {
    list += "file '" + escape_concat_entry(f) + "'\n";
  }
  return list;
}

// === Speed filter builder ===
inline std::string speed_filter(std::string_view factor) {
  std::string f(factor);
  return "setpts=" + f + "*PTS";
}

// === Probe video duration as string ===
inline std::string probe_duration_str(std::string ffprobe, std::string input) {
  long ms = probe_duration_ms(ffprobe, input);
  if (ms < 0) return "";
  char buf[32];
  snprintf(buf, sizeof(buf), "%.3f", ms / 1000.0);
  return std::string(buf);
}

// === Probe video resolution ===
inline std::string probe_resolution(std::string ffprobe, std::string input) {
  std::string cmd = ffprobe +
                    " -v quiet -select_streams v:0 -show_entries "
                    "stream=width,height -of csv=p=0 " +
                    input;
  std::string raw = process::run_capture(cmd);
  while (!raw.empty() && (raw.back() == '\n' || raw.back() == '\r'))
    raw.pop_back();
  return raw;
}

// === Write temp file (for concat lists) ===
inline std::string write_temp_file(std::string_view content,
                                   std::string_view suffix) {
  // mkstemp requires XXXXXX at end; create first, then rename with suffix
  char buf[] = "/tmp/easyffmpeg_XXXXXX";
  int fd = mkstemp(buf);
  if (fd < 0) return "";
  ssize_t written = write(fd, content.data(), content.size());
  (void)written;
  close(fd);
  if (!suffix.empty()) {
    std::string final_path = std::string(buf) + std::string(suffix);
    if (rename(buf, final_path.c_str()) == 0) return final_path;
    // rename failed; return unsuffixed path
  }
  return std::string(buf);
}

// === Remove temp file ===
inline void remove_temp_file(const std::string& path) {
  if (!path.empty()) {
#if __has_include(<filesystem>)
    std::error_code ec;
    fs::remove(path, ec);
#else
    unlink(path.c_str());
#endif
  }
}

// === atempo chain builder (atempo only supports 0.5-2.0) ===
inline std::string atempo_chain(double factor) {
  if (factor <= 0) return "atempo=1.0";
  std::string chain;
  chain.reserve(64);
  double remaining = factor;
  while (remaining > 2.0) {
    if (!chain.empty()) chain += ",";
    chain += "atempo=2.0";
    remaining /= 2.0;
  }
  while (remaining < 0.5) {
    if (!chain.empty()) chain += ",";
    chain += "atempo=0.5";
    remaining /= 0.5;
  }
  if (!chain.empty()) chain += ",";
  char buf[32];
  snprintf(buf, sizeof(buf), "%.4g", remaining);
  chain += "atempo=" + std::string(buf);
  return chain;
}

// === Build filter_complex for speed ===
inline std::string build_speed_filter_complex(std::string_view factor) {
  std::string f(factor);
  std::string audio = atempo_chain(std::stod(f));
  std::string result;
  result.reserve(32 + f.size() + audio.size());
  result = "[0:v]setpts=" + f + "*PTS[v];[0:a]" + audio + "[a]";
  return result;
}

// === Constexpr string lookup table for filter builders ===
template <size_t N>
struct FilterEntry {
  std::string_view key;
  std::string_view value;
};

template <size_t N>
[[nodiscard]] constexpr std::string_view lookup_filter(
    const FilterEntry<N> (&table)[N], std::string_view key,
    std::string_view fallback = "") {
  for (size_t i = 0; i < N; ++i) {
    if (table[i].key == key) return table[i].value;
  }
  return fallback;
}

// Format a filter string from a format string and arguments.
[[nodiscard]] inline std::string fmt_filter(std::string_view fmt,
                                            std::string_view arg) {
  std::string result;
  result.reserve(fmt.size() + arg.size());
  for (size_t i = 0; i < fmt.size(); ++i) {
    if (fmt[i] == '%' && i + 1 < fmt.size() && fmt[i + 1] == 's') {
      result += arg;
      ++i;
    } else {
      result += fmt[i];
    }
  }
  return result;
}

// === Build watermark overlay filter ===
inline std::string build_watermark_filter(std::string_view position) {
  static constexpr FilterEntry<5> table[] = {
      {"top-left", "overlay=10:10"},
      {"top-right", "overlay=main_w-overlay_w-10:10"},
      {"bottom-left", "overlay=10:main_h-overlay_h-10"},
      {"bottom-right", "overlay=main_w-overlay_w-10:main_h-overlay_h-10"},
      {"center", "overlay=(main_w-overlay_w)/2:(main_h-overlay_h)/2"}};
  return std::string(lookup_filter(table, position, "overlay=10:10"));
}

// === Build rotate filter ===
inline std::string build_rotate_filter(std::string_view angle) {
  static constexpr FilterEntry<3> table[] = {{"90", "transpose=1"},
                                             {"180", "transpose=1,transpose=1"},
                                             {"270", "transpose=2"}};
  return std::string(lookup_filter(table, angle));
}

// === Build gif filter ===
inline std::string build_gif_filter(int fps, int width) {
  return "fps=" + std::to_string(fps) + ",scale=" + std::to_string(width) +
         ":-1:flags=lanczos";
}

// === Build thumbnail filter ===
inline std::string build_thumbnail_filter(int fps) {
  return "fps=1/" + std::to_string(fps);
}

// === Build crop filter ===
inline std::string build_crop_filter(int w, int h, int x, int y) {
  return "crop=" + std::to_string(w) + ":" + std::to_string(h) + ":" +
         std::to_string(x) + ":" + std::to_string(y);
}

// === Build subtitle filter ===
inline std::string build_subtitle_filter(std::string_view srt_path) {
  // Escape ffmpeg filter special chars in path
  std::string safe;
  safe.reserve(srt_path.size() * 2);
  for (char c : srt_path) {
    if (c == '\\' || c == '\'' || c == ':' || c == '[' || c == ']')
      safe += '\\';
    safe += c;
  }
  return "subtitles=" + safe;
}

// === Build normalize filter ===
inline std::string build_normalize_filter() {
  return "loudnorm=I=-16:TP=-1.5:LRA=11";
}

// === Color helpers ===
namespace color {
[[nodiscard]] inline std::string red([[maybe_unused]] std::string_view msg) {
  return std::string("\x1B[31m") + std::string(msg) + "\x1B[0m";
}
[[nodiscard]] inline std::string bold([[maybe_unused]] std::string_view msg) {
  return std::string("\x1B[1m") + std::string(msg) + "\x1B[0m";
}
}  // namespace color
