# True Color for applications running over SSH
export COLORTERM=truecolor

# Prompt: light blue user/host, purple directory, green prompt character
PS1='\[\e[38;2;80;200;255m\]\u@\h \[\e[38;2;190;130;255m\]\w \[\e[38;2;100;230;150m\]\$\[\e[0m\] '

# Brighter directory color in ls (True Color RGB)
export LS_COLORS="${LS_COLORS}:di=38;2;100;180;255"
