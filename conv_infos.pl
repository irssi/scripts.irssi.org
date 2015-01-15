#!/usr/bin/perl
use YAML qw/LoadFile DumpFile/;

$l=LoadFile("_data/scripts.yaml");
DumpFile("_data/alt_scripts.yml",$l);
