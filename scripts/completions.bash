# bash completions for easy-ffmpeg
_easy_ffmpeg() {
  local cur="${COMP_WORDS[COMP_CWORD]}"
  local prev="${COMP_WORDS[COMP_CWORD-1]}"
  local cmds="convert compress trim resize audio-extract probe"

  if [ "$COMP_CWORD" -eq 1 ]; then
    COMPREPLY=($(compgen -W "$cmds --help -h" -- "$cur"))
    return
  fi

  local subcmd="${COMP_WORDS[1]}"
  case "$subcmd" in
    convert)
      COMPREPLY=($(compgen -W "--codec --dry-run --help -h" -- "$cur"))
      ;;
    compress)
      COMPREPLY=($(compgen -W "--web --mobile --streaming --compress --crf --preset --codec --bitrate --dry-run --help -h" -- "$cur"))
      ;;
    trim)
      COMPREPLY=($(compgen -W "--start --duration --end --copy --dry-run --help -h" -- "$cur"))
      ;;
    resize)
      COMPREPLY=($(compgen -W "--scale --width --height --dry-run --help -h" -- "$cur"))
      ;;
    audio-extract)
      COMPREPLY=($(compgen -W "--codec --bitrate --dry-run --help -h" -- "$cur"))
      ;;
    probe)
      COMPREPLY=($(compgen -W "--json --dry-run --help -h" -- "$cur"))
      ;;
  esac
}
complete -F _easy_ffmpeg easy-ffmpeg
