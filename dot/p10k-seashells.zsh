# Apply the selected SeaShells ANSI palette to any Powerlevel10k config.
# Dark source: https://github.com/odysseyalive/omarchy-seashells-theme/blob/00dca31761374d5526790dd8a10271edbc6f9ec8/omarchy/themes/seashells/colors.toml
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
  242 8
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
  esac

  if [[ ${_seashells_p10k_variant:-dark} == light ]]; then
    case $_seashells_p10k_value in
      (#e0d6c8|#0f2838|#d05023|#c8dde8|#b8a796|#027b9b|#d88821|#2d6870|#0f7b8a|#50a3b5|#4a5a65|#d38677|#618c98|#c57a1a|#0e8fb5|#3a6a75|#08131a)
        continue
        ;;
    esac
  else
    case $_seashells_p10k_value in
      (#08131a|#0f2838|#424b52|#d05023|#d38677|#027b9b|#618c98|#fba02f|#fdd29e|#2d6870|#1abcdd|#68d3f0|#bbe3ee|#50a3b5|#86abb3|#deb88d|#fee3cd|#1e4862)
        continue
        ;;
    esac
  fi

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

# The rainbow preset embeds frame colors directly rather than exposing them
# solely through a *_FOREGROUND parameter.
for _seashells_p10k_var in \
  POWERLEVEL9K_MULTILINE_FIRST_PROMPT_PREFIX \
  POWERLEVEL9K_MULTILINE_NEWLINE_PROMPT_PREFIX \
  POWERLEVEL9K_MULTILINE_LAST_PROMPT_PREFIX \
  POWERLEVEL9K_MULTILINE_FIRST_PROMPT_SUFFIX \
  POWERLEVEL9K_MULTILINE_NEWLINE_PROMPT_SUFFIX \
  POWERLEVEL9K_MULTILINE_LAST_PROMPT_SUFFIX; do
  if (( ${+parameters[$_seashells_p10k_var]} )); then
    _seashells_p10k_value=${(P)_seashells_p10k_var}
    _seashells_p10k_value=${_seashells_p10k_value//\%242F/%8F}
    typeset -g "$_seashells_p10k_var=${_seashells_p10k_value//\%244F/%8F}"
  fi
done

unset _seashells_p10k_map _seashells_p10k_var _seashells_p10k_value _seashells_p10k_replacement _seashells_p10k_variant
