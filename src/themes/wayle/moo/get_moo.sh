#!/bin/bash

moomoos=(
  "(__)\n(@@)_____\n(oo)    /|\\ \n  | |--/ | *\n  w w w  w"
  "(__)\n(OO)_____\n(oo)    /|\\ \n  | |--/ | *\n  w w w  w"
  "(__)\n(UU)_____\n(oo)    /|\\ \n  | |--/ | *\n  w w w  w"
  "(__)\n(XX)\n(oo)\\ \n/   \\ \nw  £__)"
  ".(__)\n (/\\)\n (oo)____\n /  \\    )\\ \n \\  /  e_\\ *\n  ww"
  "(__)\n(**)_____\n(oo)    /|\\ \n  | |--/ | *\n  w w w  w"
  ". __\n/(--)\\____\n (oo)   /|\\ \n  | |--/ | *\n  w w w  w"
  "(__)\n(¬¬)_____\n(oo)    /|\\ \n  | |--/ | *\n  w w w  w"
  "(__)\n(-@)\n(oo)\\ \n/   \\ \nw  £__)"
  ".(__)\n (&&)\n (oo)____\n /  \\    )\\ \n \\  /  e_\\ *\n  ww"
  "(__)\n(++)_____\n(oo)    /|\\ \n  | |--/ | *\n  w w w  w"
  "(__)\n(-+)_____\n(oo)    /|\\ \n  | |--/ | *\n  w w w  w"
  "(__)\n(@@)_____\n(OO)    /|\\ \n  | |--/ | *\n  w w w  w"
  "(__)\n(@@)\n(OO)\\ \n/   \\ \nw  £__)"
  ".(__)\n (??)\n (oo)____\n /  \\    )\\ \n \\  /  e_\\ *\n  ww"
  "(__)\n(%%)_____\n(oo)    /|\\ \n  | |--/ | *\n  w w w  w"
  "(__)\n(\$\$)_____\n(oo)    /|\\ \n  | |--/ | *\n  w w w  w"
  "(__)\n(==)_____\n(oo)    /|\\ \n  | |--/ | *\n  w w w  w"
  "(__)\n(@~)\n(oo)\\ \n/   \\ \nw  £__)"
  ".(__)\n (@#)\n (oo)____\n /  \\    )\\ \n \\  /  e_\\ *\n  ww"
  "(__)\n(##)_____\n(oo)    /|\\ \n  | |--/ | *\n  w w w  w"
  "(__)\n(!!)_____\n(oo)    /|\\ \n  | |--/ | *\n  w w w  w"
  "(__)\n(..)_____\n(oo)    /|\\ \n  | |--/ | *\n  w w w  w"
  "(__)\n(66)\n(oo)\\ \n/   \\ \nw  £__)"
)

moomoo_count=${#moomoos[@]}
random_index=$((RANDOM % moomoo_count))

while [[ -z "${moomoos[$random_index]}" ]]; do
  random_index=$((RANDOM % moomoo_count))
done

echo -e "${moomoos[$random_index]}"
