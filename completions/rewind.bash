# bash completion for rewind
_rewind_completion() {
  local cur="${COMP_WORDS[COMP_CWORD]}"
  local prev="${COMP_WORDS[COMP_CWORD - 1]}"

  case "$prev" in
    --time)
      COMPREPLY=($(compgen -W '1 hour 4 hours 1 day 3 days 1 week 2 weeks 30m 4h 2d 1w' -- "$cur"))
      return 0
      ;;
    --config)
      if [[ "$cur" == -* ]]; then
        COMPREPLY=($(compgen -W '--global --system --unset' -- "$cur"))
      else
        COMPREPLY=($(compgen -W 'timeframe' -- "$cur"))
      fi
      return 0
      ;;
  esac

  if [[ "$cur" == -* ]]; then
    COMPREPLY=($(compgen -W '--time --config --help -h' -- "$cur"))
  fi
}

complete -F _rewind_completion rewind
