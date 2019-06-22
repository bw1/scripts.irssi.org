use strict;
use vars qw($VERSION %IRSSI);

use Irssi;
use Irssi::UI;
use Irssi::TextUI;
use MIME::Base64;

$VERSION = '0.01';
%IRSSI = (
    authors	=> 'vague,bw1',
    contact	=> 'bw1@aol.at',
    name	=> 'copy',
    description	=> 'copy a line in a paste buffer of a terminal',
    license	=> 'Public Domain',
    url		=> 'https://scripts.irssi.org/',
    changed	=> '2019-06-21',
    modules => 'MIME::Base64',
    commands=> 'copy',
);

my $help = << "END";
%9Name%9
  $IRSSI{name}
%9Version%9
  $VERSION
%9Synopsis%9
  /copy [number]
%9Description%9
  $IRSSI{description}

  Tested with xterm and ssh
  see man xterm /disallowedWindowOps
%9See also%9
  https://www.freecodecamp.org/news/tmux-in-practice-integration-with-system-clipboard-bcd72c62ff7b/
END

sub cmd_copy {
	my ($args, $server, $witem)=@_;
	$args = $args-1;
	my $line=Irssi::active_win->view->{buffer}{cur_line}; 
	unless (defined $line) {
		Irssi::print('No Copy!', MSGLEVEL_CLIENTCRAP);
		return();
	}
	for(1..$args) { 
		my $l=$line->prev; 
		if (defined $l) {
			$line= $l;
		} else {
			last;
		}
	} 
	my $str=$line->get_text(0);
	my $b64=encode_base64($str,'');
	#print STDERR "\033]52;cpqs01234;".$b64."\007";
	print STDERR "\033]52;;".$b64."\007";
}

sub cmd_help {
	my ($args, $server, $witem)=@_;
	$args=~ s/\s+//g;
	if ($IRSSI{name} eq $args) {
		Irssi::print($help, MSGLEVEL_CLIENTCRAP);
		Irssi::signal_stop();
	}
}

Irssi::command_bind($IRSSI{name}, \&cmd_copy);
Irssi::command_bind('help', \&cmd_help);
