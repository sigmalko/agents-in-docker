# True Color dla aplikacji działających przez SSH
export COLORTERM=truecolor

# Prompt: błękitny użytkownik/host, fioletowy katalog, zielony znak zachęty
PS1='\[\e[38;2;80;200;255m\]\u@\h \[\e[38;2;190;130;255m\]\w \[\e[38;2;100;230;150m\]\$\[\e[0m\] '

# Jaśniejszy kolor katalogów w ls (True Color RGB)
export LS_COLORS="${LS_COLORS}:di=38;2;100;180;255"
