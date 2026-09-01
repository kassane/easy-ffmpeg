#pragma once
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <string>
#include <string_view>
#include <vector>
#ifdef _WIN32
  #include <io.h>
  #include <process.h>
  #define popen _popen
  #define pclose _pclose
#else
  #include <sys/types.h>
  #include <sys/stat.h>
  #include <unistd.h>
  #include <sys/wait.h>
#endif

namespace process {
  // Safe exec: fork+execvp on POSIX, _spawnvp on Windows.
  [[nodiscard]] inline int run_str(std::string_view cmd) {
    std::string s(cmd);
    std::vector<std::string> toks;
    std::string cur;
    for (size_t i = 0; i < s.size(); i++) {
      char c = s[i];
      if (c == ' ' || c == '\t') {
        if (!cur.empty()) { toks.push_back(cur); cur.clear(); }
      } else {
        cur += c;
      }
    }
    if (!cur.empty()) toks.push_back(cur);
    if (toks.empty()) return -1;
    std::vector<const char*> argv(toks.size() + 1);
    for (size_t i = 0; i < toks.size(); i++) argv[i] = toks[i].c_str();
    argv[toks.size()] = nullptr;
#ifdef _WIN32
    // Windows: _spawnvp blocks until child exits (same semantics as waitpid)
    intptr_t rc = _spawnvp(_P_WAIT, argv[0], const_cast<char* const*>(argv.data()));
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
#ifdef _WIN32
    return (_access(std::string(path).c_str(), 0) == 0);
#else
    struct stat st;
    return (stat(std::string(path).c_str(), &st) == 0);
#endif
  }

  // Validate path: reject .. traversal and special files (devices, symlinks, FIFOs).
  // Returns 0 if valid, 1 if path contains "..", 2 if not a regular file.
  [[nodiscard]] inline int validate_path(std::string_view path) {
    std::string p(path);
    if (p.find("..") != std::string::npos) return 1;
#ifdef _WIN32
    if (_access(p.c_str(), 0) != 0) return 2;
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
    std::string s(cmd);
    std::vector<std::string> toks;
    std::string cur;
    for (size_t i = 0; i < s.size(); i++) {
      char c = s[i];
      if (c == ' ' || c == '\t') {
        if (!cur.empty()) { toks.push_back(cur); cur.clear(); }
      } else { cur += c; }
    }
    if (!cur.empty()) toks.push_back(cur);
    if (toks.empty()) { close(pipefd[0]); close(pipefd[1]); return ""; }
    std::vector<const char*> argv(toks.size() + 1);
    for (size_t i = 0; i < toks.size(); i++) argv[i] = toks[i].c_str();
    argv[toks.size()] = nullptr;
    pid_t pid = fork();
    if (pid < 0) { close(pipefd[0]); close(pipefd[1]); return ""; }
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
    while ((n = read(pipefd[0], buf, sizeof(buf)-1)) > 0) {
      buf[n] = 0;
      result += buf;
    }
    close(pipefd[0]);
    int status;
    waitpid(pid, &status, 0);
    return result;
#endif
  }
}

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
      if (*p == '"') { in_quote = !in_quote; continue; }
      if ((*p == ' ' || *p == '\t') && !in_quote) {
        if (!cur.empty()) { g_storage.push_back(cur); cur.clear(); }
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
    size_t n = fread(buf, 1, sizeof(buf)-1, f);
    fclose(f);
    buf[n] = 0;
    size_t start = 0;
    for (size_t i = 0; i <= n; i++) {
      if (i == n || buf[i] == 0) {
        if (i > start) g_storage.push_back(std::string(buf+start, i-start));
        start = i+1;
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
      if (std::string_view(g_argv[i]) == "--help" || std::string_view(g_argv[i]) == "-h") return 1;
    return 0;
  }
  inline int has_flag(std::string_view f) {
    for (int i = 1; i < g_argc; i++)
      if (std::string_view(g_argv[i]) == f) return 1;
    return 0;
  }
  inline std::string get_flag_value(std::string_view flag) {
    for (int i = 1; i < g_argc - 1; i++)
      if (std::string_view(g_argv[i]) == flag) return std::string(g_argv[i+1]);
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
}

// === Build checks (C++ replacements for .sh scripts) ===
namespace build {
  [[nodiscard]] inline int check_no_magic() {
    std::string cmd = "grep -rn '\"\\-c:v\"\\|\"\\-b:v\"\\|\"\\-ss\"\\|\"\\-t\"\\|\"h264\"\\|\"aac\"\\|\"mp4\"\\|\"libx264\"' "
      "src --include='*.carbon' --exclude='Constants.carbon' | grep -v '//' | grep -v 'Core.PrintStr' 2>/dev/null || true";
    FILE* p = popen(cmd.c_str(), "r");
    std::vector<std::string> hits;
    if (p) { char buf[512]; while (fgets(buf, sizeof(buf), p)) hits.push_back(buf); pclose(p); }
    std::string cmd2 = "grep -rnE '(^|[^A-Za-z_])(23|1280|720|192000|2500|64)([^A-Za-z_]|$)' "
      "src --include='*.carbon' --exclude='Constants.carbon' | grep -v '//' | grep -v 'Core.PrintStr' | grep -v 'Constants\\.' 2>/dev/null || true";
    FILE* p2 = popen(cmd2.c_str(), "r");
    if (p2) { char buf[512]; while (fgets(buf, sizeof(buf), p2)) hits.push_back(buf); pclose(p2); }
    if (!hits.empty()) {
      fprintf(stderr, "Magic literal(s) outside src/core/Constants.carbon:\n");
      for (auto& h : hits) fprintf(stderr, "%s", h.c_str());
      return 1;
    }
    printf("[check-no-magic] clean\n");
    return 0;
  }
  [[nodiscard]] inline int check_no_duplication() {
    int errors = 0;
    auto count_grep = [&](const char* pat) -> int {
      std::string cmd = std::string("grep -rn '") + pat + "' src/ --include='*.carbon' 2>/dev/null | wc -l";
      FILE* p = popen(cmd.c_str(), "r");
      int n = 0;
      if (p) { fscanf(p, "%d", &n); pclose(p); }
      return n;
    };
    if (count_grep("fn Exec(") > 1) { fprintf(stderr, "Duplication: multiple fn Exec\n"); errors = 1; }
    if (count_grep("fn AddFlagValue") > 1) { fprintf(stderr, "Duplication: multiple AddFlagValue\n"); errors = 1; }
    if (!errors) printf("[check-no-duplication] clean\n");
    return errors;
  }
}

// === FFI functions called from Carbon ===
inline void print_str(std::string_view s) { printf("%.*s", (int)s.size(), s.data()); }
inline void cli_exit(int code) { std::fflush(stdout); std::exit(code); }

// === Argv builder ===
inline std::vector<std::string> g_tokens;
inline void argv_clear() { g_tokens.clear(); }
inline void argv_add_token(std::string_view t) { g_tokens.push_back(std::string(t)); }
inline std::string argv_build_cmd() {
  std::string r;
  for (size_t i = 0; i < g_tokens.size(); i++) {
    if (i) r += " ";
    if (g_tokens[i].find(' ') != std::string::npos)
      r += "\"" + g_tokens[i] + "\"";
    else
      r += g_tokens[i];
  }
  return r;
}

// === String helpers ===
namespace strh {
  inline std::string make(std::string_view s) { return std::string(s); }
  inline std::string concat3(std::string_view a, std::string_view b, std::string_view c) {
    return std::string(a) + std::string(b) + std::string(c);
  }
}

// === Escape text for ffmpeg drawtext filter ===
inline std::string escape_drawtext(std::string_view text) {
  std::string result;
  for (char c : text) {
    if (c == ':' || c == '\'' || c == '\\') result += '\\';
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

// === Probe codecs ===
[[nodiscard]] inline std::string probe_codecs(std::string ffprobe, std::string input) {
  std::string safe_input = std::string(input);
  std::string cmd = std::string(ffprobe) + " -v quiet -select_streams v:0 -show_entries stream=codec_name -of csv=p=0 " + safe_input;
  std::string raw = process::run_capture(cmd);
  while (!raw.empty() && (raw.back()=='\n'||raw.back()=='\r')) raw.pop_back();
  std::string vcodec = raw;
  std::string cmd2 = std::string(ffprobe) + " -v quiet -select_streams a:0 -show_entries stream=codec_name -of csv=p=0 " + safe_input;
  std::string raw2 = process::run_capture(cmd2);
  while (!raw2.empty() && (raw2.back()=='\n'||raw2.back()=='\r')) raw2.pop_back();
  std::string acodec = raw2;
  return vcodec + "," + acodec;
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
    std::string dir = (pos != std::string::npos) ? paths.substr(start, pos - start) : paths.substr(start);
    std::string full = dir + "/" + std::string(name);
    if (access(full.c_str(), X_OK) == 0) return full;
    if (pos != std::string::npos) start = pos + 1; else break;
  }
  return "";
}

// === Cwd + Run ===
inline std::string cwd() {
  char buf[1024];
  if (getcwd(buf, sizeof(buf))) return std::string(buf);
  return ".";
}
[[nodiscard]] inline int run(std::string_view cmd) {
  // Reuse process::run_str for safety (no shell injection)
  return process::run_str(cmd);
}

// Run command through shell (allows glob expansion, for build tool only)
[[nodiscard]] inline int run_shell(std::string_view cmd) {
  return std::system(std::string(cmd).c_str());
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
        fprintf(stderr, "\r[%-50s] %d%%", std::string(pct / 2, '#').c_str(), pct);
      } else {
        int sec = (int)(ms / 1000);
        fprintf(stderr, "\r[%ds]", sec);
      }
    }
  }
  int rc = _pclose(p);
  if (total_ms > 0) fprintf(stderr, "\r[%-50s] 100%%\n", std::string(50, '#').c_str());
  else fprintf(stderr, "\n");
  return rc;
#else
  // POSIX: fork+execvp with pipe for safe progress parsing
  int pipefd[2];
  if (pipe(pipefd) < 0) return process::run_str(cmd);
  std::string s(cmd);
  std::vector<std::string> toks;
  std::string cur;
  for (size_t i = 0; i < s.size(); i++) {
    char c = s[i];
    if (c == ' ' || c == '\t') {
      if (!cur.empty()) { toks.push_back(cur); cur.clear(); }
    } else { cur += c; }
  }
  if (!cur.empty()) toks.push_back(cur);
  if (toks.empty()) { close(pipefd[0]); close(pipefd[1]); return -1; }
  std::vector<const char*> argv(toks.size() + 1);
  for (size_t i = 0; i < toks.size(); i++) argv[i] = toks[i].c_str();
  argv[toks.size()] = nullptr;
  pid_t pid = fork();
  if (pid < 0) { close(pipefd[0]); close(pipefd[1]); return process::run_str(cmd); }
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
  if (!p) { waitpid(pid, nullptr, 0); return -1; }
  char buf[1024];
  while (fgets(buf, sizeof(buf), p)) {
    std::string line(buf);
    size_t pos = line.find("out_time_ms=");
    if (pos != std::string::npos) {
      long ms = std::stol(line.substr(pos + 12));
      if (total_ms > 0) {
        int pct = (int)((ms * 100) / total_ms);
        if (pct > 100) pct = 100;
        fprintf(stderr, "\r[%-50s] %d%%", std::string(pct / 2, '#').c_str(), pct);
      } else {
        int sec = (int)(ms / 1000);
        fprintf(stderr, "\r[%ds]", sec);
      }
    }
  }
  fclose(p);
  int status;
  waitpid(pid, &status, 0);
  if (total_ms > 0) fprintf(stderr, "\r[%-50s] 100%%\n", std::string(50, '#').c_str());
  else fprintf(stderr, "\n");
  if (WIFEXITED(status)) return WEXITSTATUS(status);
  return -1;
#endif
}

// Get duration in milliseconds via ffprobe. Returns -1 on error.
[[nodiscard]] inline long probe_duration_ms(std::string ffprobe, std::string input) {
  std::string safe_input = std::string(input);
  std::string cmd = std::string(ffprobe) + " -v quiet -show_entries format=duration -of csv=p=0 " + safe_input;
  std::string raw = process::run_capture(cmd);
  if (raw.empty()) return -1;
  try { return (long)(std::stod(raw) * 1000); } catch (...) {}
  return -1;
}

// Resolve carbon binary: PATH first, then vendored toolchain.
[[nodiscard]] inline std::string resolve_carbon() {
  std::string from_path = find_in_path("carbon");
  if (!from_path.empty()) return from_path;
  return cwd() + "/carbon_toolchain-0.0.0-0.nightly.2026.08.29/bin/carbon";
}

// === String-to-int conversion (Carbon has no stoi) ===
[[nodiscard]] inline int stoi(std::string s) {
  try { return std::stoi(s); } catch (...) { return 0; }
}

// === Validate string is numeric (digits, optional dot, optional leading -) ===
[[nodiscard]] inline int validate_numeric(std::string s) {
  if (s.empty()) return 0;
  size_t start = 0;
  if (s[0] == '-' || s[0] == '+') start = 1;
  if (start >= s.size()) return 0;
  int dots = 0;
  for (size_t i = start; i < s.size(); i++) {
    if (s[i] == '.') { dots++; if (dots > 1) return 0; }
    else if (s[i] < '0' || s[i] > '9') return 0;
  }
  return 1;
}

// === Concat file list builder (2 files) ===
inline std::string build_concat_list_2(std::string_view a, std::string_view b) {
  return "file '" + std::string(a) + "'\nfile '" + std::string(b) + "'\n";
}

// === Concat file list builder (vector) ===
inline std::string build_concat_list(const std::vector<std::string>& files) {
  std::string list;
  for (auto& f : files) {
    list += "file '" + f + "'\n";
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
  std::string cmd = ffprobe + " -v quiet -show_entries format=duration -of csv=p=0 " + input;
  std::string raw = process::run_capture(cmd);
  while (!raw.empty() && (raw.back()=='\n'||raw.back()=='\r')) raw.pop_back();
  return raw;
}

// === Probe video resolution ===
inline std::string probe_resolution(std::string ffprobe, std::string input) {
  std::string cmd = ffprobe + " -v quiet -select_streams v:0 -show_entries stream=width,height -of csv=p=0 " + input;
  std::string raw = process::run_capture(cmd);
  while (!raw.empty() && (raw.back()=='\n'||raw.back()=='\r')) raw.pop_back();
  return raw;
}

// === Write temp file (for concat lists) ===
inline std::string write_temp_file(std::string_view content, std::string_view suffix) {
  char tmpl[] = "/tmp/easyffmpeg_XXXXXX";
  int fd = mkstemp(tmpl);
  if (fd < 0) return "";
  std::string path(tmpl);
  write(fd, content.data(), content.size());
  close(fd);
  return path;
}

// === Remove temp file ===
inline void remove_temp_file(const std::string& path) {
  if (!path.empty()) unlink(path.c_str());
}

// === atempo chain builder (atempo only supports 0.5-2.0) ===
inline std::string atempo_chain(double factor) {
  if (factor <= 0) return "atempo=1.0";
  std::string chain;
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
  return "[0:v]setpts=" + f + "*PTS[v];[0:a]" + audio + "[a]";
}

// === Build watermark overlay filter ===
inline std::string build_watermark_filter(std::string position) {
  if (position == "top-left") return "overlay=10:10";
  if (position == "top-right") return "overlay=main_w-overlay_w-10:10";
  if (position == "bottom-left") return "overlay=10:main_h-overlay_h-10";
  if (position == "bottom-right") return "overlay=main_w-overlay_w-10:main_h-overlay_h-10";
  if (position == "center") return "overlay=(main_w-overlay_w)/2:(main_h-overlay_h)/2";
  return "overlay=10:10";
}

// === Build rotate filter ===
inline std::string build_rotate_filter(std::string angle) {
  if (angle == "90") return "transpose=1";
  if (angle == "180") return "transpose=1,transpose=1";
  if (angle == "270") return "transpose=2";
  return "";
}

// === Build gif filter ===
inline std::string build_gif_filter(int fps, int width) {
  std::string w = std::to_string(width);
  return "fps=" + std::to_string(fps) + ",scale=" + w + ":-1:flags=lanczos";
}

// === Build thumbnail filter ===
inline std::string build_thumbnail_filter(int fps) {
  return "fps=1/" + std::to_string(fps);
}

// === Build replace-audio command ===
inline std::string build_replace_audio_cmd(std::string ffmpeg, std::string input, std::string audio, std::string output) {
  return ffmpeg + " -y -i " + input + " -i " + audio + " -map 0:v -map 1:a -c:v copy -shortest " + output;
}

// === Build subtitle filter ===
inline std::string build_subtitle_filter(std::string srt_path) {
  return "subtitles=" + srt_path;
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
}
