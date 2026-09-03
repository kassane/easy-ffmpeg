# bash completions for easy-ffmpeg
_easy_ffmpeg() {
  local cur="${COMP_WORDS[COMP_CWORD]}"
  local prev="${COMP_WORDS[COMP_CWORD-1]}"
  local cmds="convert compress trim resize audio-extract probe concat gif thumbnail speed rotate watermark subtitle metadata normalize replace-audio crop colordetect"

  if [ "$COMP_CWORD" -eq 1 ]; then
    COMPREPLY=($(compgen -W "$cmds --help -h --version -v --dry-run --force" -- "$cur"))
    return
  fi

  local subcmd="${COMP_WORDS[1]}"
  case "$subcmd" in
    convert)
      COMPREPLY=($(compgen -W "--codec --no-subs --dry-run --help -h --force" -- "$cur")) ;;
    compress)
      COMPREPLY=($(compgen -W "--web --mobile --streaming --compress --crf --preset --codec --audio-codec --video-bitrate --bitrate --av1 --jxl --no-subs --dry-run --help -h --force" -- "$cur")) ;;
    trim)
      COMPREPLY=($(compgen -W "--start --duration --end --sseof --copy --dry-run --help -h --force" -- "$cur")) ;;
    resize)
      COMPREPLY=($(compgen -W "--scale --width --height --dry-run --help -h --force" -- "$cur")) ;;
    audio-extract)
      COMPREPLY=($(compgen -W "--codec --bitrate --dry-run --help -h --force" -- "$cur")) ;;
    probe)
      COMPREPLY=($(compgen -W "--json --dry-run --help -h --force" -- "$cur")) ;;
    concat)
      COMPREPLY=($(compgen -W "--copy --codec --dry-run --help -h --force" -- "$cur")) ;;
    gif)
      COMPREPLY=($(compgen -W "--fps --width --dry-run --help -h --force" -- "$cur")) ;;
    thumbnail)
      COMPREPLY=($(compgen -W "--time --every --webp --dry-run --help -h --force" -- "$cur")) ;;
    speed)
      COMPREPLY=($(compgen -W "--factor --dry-run --help -h --force" -- "$cur")) ;;
    rotate)
      COMPREPLY=($(compgen -W "--angle --flip --dry-run --help -h --force" -- "$cur")) ;;
    watermark)
      COMPREPLY=($(compgen -W "--image --text --position --dry-run --help -h --force" -- "$cur")) ;;
    subtitle)
      COMPREPLY=($(compgen -W "--file --dry-run --help -h --force" -- "$cur")) ;;
    metadata)
      COMPREPLY=($(compgen -W "--strip --title --artist --dry-run --help -h --force" -- "$cur")) ;;
    normalize)
      COMPREPLY=($(compgen -W "--dry-run --help -h --force" -- "$cur")) ;;
    replace-audio)
      COMPREPLY=($(compgen -W "--audio --dry-run --help -h --force" -- "$cur")) ;;
    crop)
      COMPREPLY=($(compgen -W "--width --height --x --y --dry-run --help -h --force" -- "$cur")) ;;
    colordetect)
      COMPREPLY=($(compgen -W "--dry-run --help -h --force" -- "$cur")) ;;
  esac
}
complete -F _easy_ffmpeg easy-ffmpeg
