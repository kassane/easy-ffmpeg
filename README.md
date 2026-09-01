# easy-ffmpeg

`easy-ffmpeg` wraps the common cases with typed subcommands, smart defaults, and built-in presets — no RTFM required.

## Quick Example

```sh
$ easy-ffmpeg compress video.mp4 output.mp4 --web
ffmpeg -y -i video.mp4 -c:v libx264 -crf 23 -preset medium -c:a aac -b:a 128k -movflags +faststart output.mp4
exit code=0

$ easy-ffmpeg convert old.mkv new.mp4          # smart remux (h264+aac → -c copy)
$ easy-ffmpeg resize photo.mp4 scaled.mp4 --scale hd
$ easy-ffmpeg trim clip.mp4 out.mp4 --start 00:01:00 --duration 30
$ easy-ffmpeg audio-extract movie.mp4 sound.mp3
$ easy-ffmpeg probe movie.mp4 --json
```

## Commands

| Command | What | Example |
|---------|------|---------|
| `convert` | Format conversion + **smart remux** | `convert in.mkv out.mp4 --codec h264` |
| `compress` | Encode with quality presets | `compress in.mp4 out.mp4 --web` |
| `trim` | Cut a segment | `trim in.mp4 out.mp4 --start 00:01:00 --duration 30` |
| `resize` | Scale dimensions | `resize in.mp4 out.mp4 --scale hd` |
| `audio-extract` | Strip video, keep audio | `audio-extract in.mp4 out.mp3` |
| `probe` | Inspect media metadata | `probe in.mp4 --json` |
| `concat` | Merge multiple videos | `concat a.mp4 b.mp4 merged.mp4 --copy` |
| `gif` | Video to animated GIF | `gif video.mp4 anim.gif --fps 10` |
| `thumbnail` | Extract a frame as image | `thumbnail video.mp4 thumb.jpg --time 00:01:30` |
| `speed` | Change playback speed | `speed video.mp4 fast.mp4 --factor 2.0` |
| `rotate` | Rotate or flip video | `rotate video.mp4 rot.mp4 --angle 90` |
| `watermark` | Image or text overlay | `watermark video.mp4 out.mp4 --text Sample` |
| `subtitle` | Burn subtitles into video | `subtitle video.mp4 out.mp4 --file subs.srt` |
| `metadata` | Strip or set metadata | `metadata video.mp4 clean.mp4 --strip` |
| `normalize` | Normalize audio levels | `normalize video.mp4 loud.mp4` |
| `replace-audio` | Replace audio track | `replace-audio video.mp4 out.mp4 --audio music.mp3` |

Every command supports `--dry-run` — prints the exact ffmpeg command without executing.

### Presets (`compress`)

| Flag | Video | CRF | Audio | Extras |
|------|-------|-----|-------|--------|
| `--web` | H.264 | 23 | AAC 128k | faststart |
| `--mobile` | H.264 | 26 | AAC 96k | scale 720p |
| `--streaming` | H.265 | 18 | AAC 256k | — |
| `--compress` | H.265 | 28 | AAC 128k | small file |

### Scale presets (`resize`)

`--scale icon` (240p) · `--scale retro` (480p) · `--scale hd` (720p) · `--scale fullhd` (1080p) · `--scale 2k` (1440p)
`--scale tiktok` (1080x1920) · `--scale instagram` (1080x1080) · `--scale youtube` (1920x1080)

### Smart remux

When `convert` sees h264+aac input going to mp4, it skips re-encoding entirely:

```sh
$ easy-ffmpeg convert h264_aac.mkv output.mp4 --dry-run
ffmpeg -y -i h264_aac.mkv -c:v copy -c:a copy output.mp4   # instant, zero quality loss
```

## Build

```sh
# make build tool
carbon build \
            build.carbon \
            src/core/ArgsBuilder.carbon \
            src/core/Constants.carbon \
            --output=build \
            -- -std=c++23 -Isrc/core
./build              # build only
./build --verbose    # build verbosed
./build --once       # build + all tests
./build --ci         # format + lint + build + smoke
./build --check      # validation only
./build --clean      # remove artifacts
```

Requirements: `ffmpeg >= 6`, `ffprobe`.

## License
See [MIT-LICENSE](LICENSE) - FFmpeg is an external dependency.
