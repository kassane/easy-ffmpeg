// All magic strings, numbers, and codec choices in one place.
// Functions, not `let` constants: cross-package `let` crashes this nightly.
package Constants library "core/constants";

// ── Version ────────────────────────────────────────────────────────────────
fn Version() -> Core.String { return "0.2.2"; }

// ── Exit codes ─────────────────────────────────────────────────────────────
fn ExitSuccess() -> i32 { return 0; }
fn ExitFailure() -> i32 { return 1; }
fn ExitUsage() -> i32 { return 2; }
fn ExitCodecNotAllowed() -> i32 { return 2; }
fn ExitFileNotFound() -> i32 { return 3; }
fn NotFoundIndex() -> u64 { return 18446744073709551615; }
fn ExitSecurity() -> i32 { return 4; }

// ── Binaries ───────────────────────────────────────────────────────────────
fn FfmpegBin() -> Core.String { return "ffmpeg"; }
fn FfprobeBin() -> Core.String { return "ffprobe"; }

// ── Codec whitelist ────────────────────────────────────────────────────────
fn CodecH264() -> Core.String { return "h264"; }
fn CodecAac() -> Core.String { return "aac"; }
fn CodecMp3() -> Core.String { return "mp3"; }
fn CodecVp9() -> Core.String { return "vp9"; }
fn CodecAv1() -> Core.String { return "av1"; }
fn CodecLibx264() -> Core.String { return "libx264"; }
fn CodecLibx265() -> Core.String { return "libx265"; }
fn CodecLibmp3lame() -> Core.String { return "libmp3lame"; }
fn FlagCodecCopy() -> Core.String { return "copy"; }


// ── Default format ─────────────────────────────────────────────────────────
fn DefaultFormat() -> Core.String { return "mp4"; }

// ── ffmpeg flags ───────────────────────────────────────────────────────────
fn FlagInput() -> Core.String { return "-i"; }
fn FlagOutputCodec() -> Core.String { return "-c:v"; }
fn FlagAudioCodec() -> Core.String { return "-c:a"; }
fn FlagFormat() -> Core.String { return "-f"; }
fn FlagQscale() -> Core.String { return "-qscale:v"; }
fn FlagStart() -> Core.String { return "-ss"; }
fn FlagTo() -> Core.String { return "-to"; }
fn FlagDuration() -> Core.String { return "-t"; }
fn FlagSseof() -> Core.String { return "-sseof"; }
fn FlagFilter() -> Core.String { return "-vf"; }
fn FlagFilterComplex() -> Core.String { return "-filter_complex"; }
fn FlagMap() -> Core.String { return "-map"; }
fn FlagAudioFilter() -> Core.String { return "-af"; }
fn FlagVframes() -> Core.String { return "-vframes"; }
fn FlagSafe() -> Core.String { return "-safe"; }
fn FlagAnnotate() -> Core.String { return "-an"; }
fn FlagVn() -> Core.String { return "-vn"; }
fn FlagOverwrite() -> Core.String { return "-y"; }
fn FlagShortest() -> Core.String { return "-shortest"; }

// ── Encoding quality flags ─────────────────────────────────────────────────
fn FlagCrf() -> Core.String { return "-crf"; }
fn FlagPreset() -> Core.String { return "-preset"; }
fn FlagAudioBr() -> Core.String { return "-b:a"; }
fn FlagVideoBitrate() -> Core.String { return "-b:v"; }
fn FlagMovflags() -> Core.String { return "-movflags"; }
fn FaststartValue() -> Core.String { return "+faststart"; }

// ── Metadata flags ─────────────────────────────────────────────────────────
fn FlagMetadataTitle() -> Core.String { return "-metadata"; }
fn FlagMapMetadata() -> Core.String { return "-map_metadata"; }

// ── CLI flags ──────────────────────────────────────────────────────────────
fn FlagDryRun() -> Core.String { return "--dry-run"; }
fn FlagHelp() -> Core.String { return "--help"; }
fn FlagVersion() -> Core.String { return "--version"; }

// ── ffprobe flags ──────────────────────────────────────────────────────────
fn FlagVerbosity() -> Core.String { return "-v"; }
fn FlagPrintFormat() -> Core.String { return "-print_format"; }
fn FlagShowStreams() -> Core.String { return "-show_streams"; }
fn QuietValue() -> Core.String { return "quiet"; }
fn JsonValue() -> Core.String { return "json"; }

// ── Quality presets ────────────────────────────────────────────────────────
fn QualityHigh() -> i32 { return 1; }
fn QualityMedium() -> i32 { return 2; }
fn QualityLow() -> i32 { return 3; }
fn DefaultQuality() -> i32 { return QualityMedium(); }
fn MaxArgs() -> i32 { return 64; }

// ── Encoding defaults ──────────────────────────────────────────────────────
fn DefaultCrf() -> Core.String { return "23"; }
fn DefaultPreset() -> Core.String { return "fast"; }
fn DefaultAudioBitrate() -> Core.String { return "128k"; }
fn DefaultGifFps() -> i32 { return 15; }
fn DefaultGifWidth() -> i32 { return 480; }
fn DefaultThumbnailTime() -> Core.String { return "00:00:05"; }

// ── Compress presets ───────────────────────────────────────────────────────
fn PresetWebCrf() -> Core.String { return "23"; }
fn PresetWebPreset() -> Core.String { return "medium"; }
fn PresetWebAudioBr() -> Core.String { return "128k"; }
fn PresetMobileCrf() -> Core.String { return "26"; }
fn PresetMobilePreset() -> Core.String { return "medium"; }
fn PresetMobileAudioBr() -> Core.String { return "96k"; }
fn PresetMobileMaxH() -> Core.String { return "720"; }
fn PresetStreamingCrf() -> Core.String { return "18"; }
fn PresetStreamingPreset() -> Core.String { return "medium"; }
fn PresetStreamingAudioBr() -> Core.String { return "256k"; }
fn PresetCompressCrf() -> Core.String { return "28"; }
fn PresetCompressPreset() -> Core.String { return "medium"; }
fn PresetCompressAudioBr() -> Core.String { return "128k"; }

// ── Scale presets ──────────────────────────────────────────────────────────
fn ScaleHd() -> Core.String { return "720"; }
fn ScaleFullhd() -> Core.String { return "1080"; }
fn Scale2k() -> Core.String { return "1440"; }
fn ScaleRetro() -> Core.String { return "480"; }
fn ScaleIcon() -> Core.String { return "240"; }
fn ScaleFilterHd() -> Core.String { return "scale=-2:720"; }
fn ScaleTiktok() -> Core.String { return "1080:1920"; }
fn ScaleInstagram() -> Core.String { return "1080:1080"; }
fn ScaleYoutube() -> Core.String { return "1920:1080"; }

// ── Speed presets ──────────────────────────────────────────────────────────
fn SpeedHalf() -> Core.String { return "0.5"; }
fn SpeedDouble() -> Core.String { return "2.0"; }

// ── Rotation presets ───────────────────────────────────────────────────────
fn Rotate90() -> Core.String { return "1"; }
fn Rotate180() -> Core.String { return "2"; }
fn Rotate270() -> Core.String { return "3"; }

// ── Command names ──────────────────────────────────────────────────────────
fn CmdConcat() -> Core.String { return "concat"; }
fn CmdGif() -> Core.String { return "gif"; }
fn CmdThumbnail() -> Core.String { return "thumbnail"; }
fn CmdSpeed() -> Core.String { return "speed"; }
fn CmdRotate() -> Core.String { return "rotate"; }
fn CmdWatermark() -> Core.String { return "watermark"; }
fn CmdSubtitle() -> Core.String { return "subtitle"; }
fn CmdMetadata() -> Core.String { return "metadata"; }
fn CmdNormalize() -> Core.String { return "normalize"; }
fn SafeZero() -> Core.String { return "0"; }
fn VframesOne() -> Core.String { return "1"; }
fn CmdReplaceAudio() -> Core.String { return "replace-audio"; }

// ── AV1 presets ──────────────────────────────────────────────────────
fn PresetAv1Crf() -> Core.String { return "30"; }
fn PresetAv1Preset() -> Core.String { return "medium"; }
fn PresetAv1AudioBr() -> Core.String { return "128k"; }
fn CodecLibsvtav1() -> Core.String { return "libsvtav1"; }
