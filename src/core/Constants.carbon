// All magic strings, numbers, and codec choices in one place.
// Functions, not `let` constants: cross-package `let` crashes this nightly.
package Constants library "core/constants";
import Core library "prelude/types";

// Exit codes
fn ExitSuccess() -> i32 { return 0; }
fn ExitFailure() -> i32 { return 1; }
fn ExitCodecNotAllowed() -> i32 { return 2; }
fn ExitFileNotFound() -> i32 { return 3; }
fn ExitSecurity() -> i32 { return 4; }

fn FfmpegBin() -> Core.String { return "ffmpeg"; }
fn DefaultFormat() -> Core.String { return "mp4"; }

// Codec whitelist
fn CodecH264() -> Core.String { return "h264"; }
fn CodecAac() -> Core.String { return "aac"; }
fn CodecMp3() -> Core.String { return "mp3"; }
fn CodecVp9() -> Core.String { return "vp9"; }
fn CodecAv1() -> Core.String { return "av1"; }

// Flags
fn FlagInput() -> Core.String { return "-i"; }
fn FlagOutputCodec() -> Core.String { return "-c:v"; }
fn FlagAudioCodec() -> Core.String { return "-c:a"; }
fn FlagFormat() -> Core.String { return "-f"; }
fn FlagQscale() -> Core.String { return "-qscale:v"; }
fn FlagStart() -> Core.String { return "-ss"; }
fn FlagDuration() -> Core.String { return "-t"; }
fn FlagFilter() -> Core.String { return "-vf"; }
fn FlagMap() -> Core.String { return "-map"; }
fn FlagAnnotate() -> Core.String { return "-an"; }
fn FlagVn() -> Core.String { return "-vn"; }
fn FlagOverwrite() -> Core.String { return "-y"; }
fn FlagDryRun() -> Core.String { return "--dry-run"; }
fn FlagHelp() -> Core.String { return "--help"; }
fn FlagVersion() -> Core.String { return "--version"; }

// Quality presets
fn QualityHigh() -> i32 { return 1; }
fn QualityMedium() -> i32 { return 2; }
fn QualityLow() -> i32 { return 3; }
fn DefaultQuality() -> i32 { return QualityMedium(); }
fn MaxArgs() -> i32 { return 64; }

fn CodecCopy() -> Core.String { return "copy"; }
fn CodecLibx264() -> Core.String { return "libx264"; }
fn CodecLibx265() -> Core.String { return "libx265"; }
fn CodecLibmp3lame() -> Core.String { return "libmp3lame"; }

fn FfprobeBin() -> Core.String { return "ffprobe"; }

fn DefaultCrf() -> Core.String { return "23"; }
fn DefaultPreset() -> Core.String { return "fast"; }
fn DefaultAudioBitrate() -> Core.String { return "128k"; }

// Scale presets
fn ScaleHd() -> Core.String { return "720"; }
fn ScaleFullhd() -> Core.String { return "1080"; }
fn Scale2k() -> Core.String { return "1440"; }
fn ScaleRetro() -> Core.String { return "480"; }
fn ScaleIcon() -> Core.String { return "240"; }

// Preset defaults (web/mobile/compress/streaming)
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

// Codec detection names (from ffprobe output)
fn CodecNameH264() -> Core.String { return "h264"; }
fn CodecNameAac() -> Core.String { return "aac"; }
fn FlagCodecCopy() -> Core.String { return "copy"; }

fn ExitUsage() -> i32 { return 2; }

fn FlagTo() -> Core.String { return "-to"; }
fn FlagMovflags() -> Core.String { return "-movflags"; }
fn FaststartValue() -> Core.String { return "+faststart"; }
fn ScaleFilterHd() -> Core.String { return "scale=-2:720"; }

fn FlagAudioBr() -> Core.String { return "-b:a"; }
fn FlagCrf() -> Core.String { return "-crf"; }
fn FlagPreset() -> Core.String { return "-preset"; }

fn FlagVerbosity() -> Core.String { return "-v"; }
fn FlagPrintFormat() -> Core.String { return "-print_format"; }
fn FlagShowStreams() -> Core.String { return "-show_streams"; }
fn QuietValue() -> Core.String { return "quiet"; }
fn JsonValue() -> Core.String { return "json"; }

// Version
fn Version() -> Core.String { return "0.1.0"; }
