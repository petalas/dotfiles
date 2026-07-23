# SeaShells command-line colors.
#
# These use only the terminal's ANSI 0-15 palette, whose exact SeaShells hex
# values live in the Ghostty and Kitty configs. Keeping semantic colors here
# indexed means command output follows the same palette in either terminal.

# GNU ls, shell completion, and tools that understand LS_COLORS.
export LS_COLORS='rs=0:fi=0:di=01;94:ln=96:mh=00:pi=33:so=95:do=95:bd=01;93:cd=01;93:or=01;91:mi=00:su=97;41:sg=30;43:ca=00:tw=30;42:ow=94;42:st=97;44:ex=01;92'

# eza file names, metadata, UI, and built-in file categories. EZA_COLORS
# overrides LS_COLORS and avoids eza's unrelated 256-color defaults.
export EZA_COLORS='di=1;94:ex=1;92:fi=37:pi=33:so=95:bd=1;93:cd=1;93:ln=96:or=1;91:oc=96:ur=92:uw=93:ux=91:ue=91:gr=92:gw=93:gx=91:tr=92:tw=93:tx=91:su=91:sf=91:xa=95:sn=37:nb=90:nk=37:nm=93:ng=91:nt=95:sb=90:ub=90:uk=90:um=90:ug=90:ut=90:df=93:ds=93:uu=93:uR=91:un=37:gu=96:gR=91:gn=37:lc=90:lm=93:ga=92:gm=93:gd=91:gv=96:gt=95:gi=90:gc=1;91:Gm=94:Go=96:Gc=92:Gd=93:xx=90:da=90:in=90:bl=90:hd=1;93:lp=96:cc=91:bO=1;91:sp=95:mp=94:im=95:vi=35:mu=96:lo=36:cr=91:do=94:co=91:tm=90:cm=93:bu=93:sc=92:ic=96:Sn=90:Su=93:Sr=96:St=94:Sl=95:ff=90'
