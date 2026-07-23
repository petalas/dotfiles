# Apply the terminal's SeaShells ANSI palette to any Powerlevel10k config.
# Source this after ~/.p10k.zsh so it can normalize wizard-generated colors.

# Powerlevel10k's rainbow preset mostly uses ANSI colors already, but it also
# emits xterm-256 colors. Map those known colors to the closest semantic
# SeaShells slot. Unknown custom colors fall back to the normal foreground or
# background, ensuring the prompt never escapes the managed palette.
typeset -A _seashells_p10k_map=(
  28  2
  67  10
  76  10
  196 9
  208 3
  232 0
  240 8
  244 8
  250 14
  254 15
  255 15
)

for _seashells_p10k_var in ${(k)parameters[(I)POWERLEVEL9K_*_(FOREGROUND|BACKGROUND)]}; do
  [[ ${(tP)_seashells_p10k_var} == *scalar* ]] || continue
  _seashells_p10k_value=${(P)_seashells_p10k_var}

  case $_seashells_p10k_value in
    (''|<0-15>|black|red|green|yellow|blue|magenta|cyan|white|gray|grey)
      continue
      ;;
    (#08131a|#17384c|#424b52|#d05023|#d38677|#027b9b|#618c98|#fba02f|#fdd29e|#1d4850|#1abcdd|#68d3f0|#bbe3ee|#50a3b5|#86abb3|#deb88d|#fee3cd)
      continue
      ;;
  esac

  _seashells_p10k_replacement=${_seashells_p10k_map[$_seashells_p10k_value]-}
  if [[ -z $_seashells_p10k_replacement ]]; then
    if [[ $_seashells_p10k_var == *_BACKGROUND ]]; then
      _seashells_p10k_replacement=0
    else
      _seashells_p10k_replacement=7
    fi
  fi
  typeset -g "$_seashells_p10k_var=$_seashells_p10k_replacement"
done

# The rainbow preset embeds color 244 directly in its multiline frame rather
# than exposing it solely through a *_FOREGROUND parameter.
for _seashells_p10k_var in \
  POWERLEVEL9K_MULTILINE_FIRST_PROMPT_PREFIX \
  POWERLEVEL9K_MULTILINE_NEWLINE_PROMPT_PREFIX \
  POWERLEVEL9K_MULTILINE_LAST_PROMPT_PREFIX \
  POWERLEVEL9K_MULTILINE_FIRST_PROMPT_SUFFIX \
  POWERLEVEL9K_MULTILINE_NEWLINE_PROMPT_SUFFIX \
  POWERLEVEL9K_MULTILINE_LAST_PROMPT_SUFFIX; do
  if (( ${+parameters[$_seashells_p10k_var]} )); then
    _seashells_p10k_value=${(P)_seashells_p10k_var}
    typeset -g "$_seashells_p10k_var=${_seashells_p10k_value//\%244F/%8F}"
  fi
done

unset _seashells_p10k_map _seashells_p10k_var _seashells_p10k_value _seashells_p10k_replacement
