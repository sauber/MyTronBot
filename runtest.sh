#!/bin/sh

cd perl
perl -Mstrict -Mwarnings -c MyTronBot.pl || exit
#java -jar engine/Tron.jar maps/empty-room.txt "perl MyTronBot.pl" "java -jar example_bots/RandomBot.jar"
#java -jar engine/Tron.jar maps/ring.txt "perl MyTronBot.pl" "java -jar example_bots/RandomBot.jar"
java -jar engine/Tron.jar maps/ring.txt "perl MyTronBot.pl" "java -jar example_bots/Chaser.jar"
