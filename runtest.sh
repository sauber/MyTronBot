#!/bin/sh

cd perl
perl -c MyTronBot.pl
#java -jar engine/Tron.jar maps/empty-room.txt "perl MyTronBot.pl" "java -jar example_bots/RandomBot.jar"
java -jar engine/Tron.jar maps/ring.txt "perl MyTronBot.pl" "java -jar example_bots/RandomBot.jar"
#java -jar engine/Tron.jar maps/empty-room.txt "perl MyTronBot.pl" "java -jar example_bots/Chaser.jar"
