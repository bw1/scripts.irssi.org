use strict;
use vars qw($VERSION %IRSSI);

use Irssi;
use Irssi::UI;
use Irssi::TextUI;
use MIME::Base64;

$VERSION = '0.02';
%IRSSI = (
    authors	=> 'vague,bw1',
    contact	=> 'bw1@aol.at',
    name	=> 'copy',
    description	=> 'copy a line in a paste buffer of a terminal',
    license	=> 'Public Domain',
    url		=> 'https://scripts.irssi.org/',
    changed	=> '2019-06-23',
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

  Tested with xterm, tmux, screen and ssh
  see man xterm /disallowedWindowOps
%9Settings%9
  $IRSSI{name}_selection
    c   clipboard
    p   primary
    q   secondary
    s   select
    0-7 cut buffers
  $IRSSI{name}_method
    xterm
	xclip
%9See also%9
  https://www.freecodecamp.org/news/tmux-in-practice-integration-with-system-clipboard-bcd72c62ff7b/
  http://anti.teamidiot.de/static/nei/*/Code/urxvt/
  https://invisible-island.net/xterm/ctlseqs/ctlseqs.html#h2-Operating-System-Commands
END

# TODO
#
# by dive
# /tmp/screen-exchange
#
# by nei
# http://anti.teamidiot.de/static/nei/*/Code/urxvt/
#
# by vague
# line buffer

my ($copy_selection, $copy_method);

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
    if ( $copy_method eq 'xterm' ) {
        paste($str, $copy_selection);
    } elsif ( $copy_method eq 'xclip' ) {
        paste_xclip($str, $copy_selection);
    }
}

sub paste_xclip {
    my ($str, $par)= @_;
    my %ma= (
        0=>'buffer-cut',
        p=>'primary',
        q=>'secondary',
        c=>'clipboard',
    );
    my $sel= $ma{substr($par,0,1)};
    if (defined $sel) {
        $sel= "-selection $sel";
    }
    my $cmd="xclip -i $sel";
    open my $fa, "|-", $cmd;
    print $fa $str;
    close $fa;
}

sub paste {
	my ($str,$par)=@_;
	my $b64=encode_base64($str,'');
	#print STDERR "\033]52;cpqs01234;".$b64."\007";
	my $pstr="\033]52;".$par.";".$b64."\007";
	if ($ENV{TERM} =~ m/^xterm/) {
		print STDERR  $pstr;
	} elsif ($ENV{TERM} eq 'screen') {
		# tmux
		if (defined $ENV{TMUX}) {
			my $tc = `tmux list-clients`;
			$ENV{TMUX} =~ m/,(\d+)$/;
			my $tcn =$1;
			my $pty;
			foreach (split /\n/,$tc) {
				$_ =~ m/^(.*?): (\d+)/;
				if ($tcn == $2) {
					$pty = $1;
					last();
				}
			}
			my $fa;
			open $fa,'>',$pty;
			print $fa $pstr;
			close $fa;
		# screen
		} elsif (defined $ENV{STY}) {
			$ENV{STY} =~ m/\..*?-(\d+)\./;
			my $pty = "/dev/pts/$1";
			my $fa;
			open $fa,'>',$pty;
			print $fa $pstr;
			close $fa;
		}
	}
}

sub cmd_help {
	my ($args, $server, $witem)=@_;
	$args=~ s/\s+//g;
	if ($IRSSI{name} eq $args) {
		Irssi::print($help, MSGLEVEL_CLIENTCRAP);
		Irssi::signal_stop();
	}
}

sub sig_setup_changed {
	my $cs= Irssi::settings_get_str($IRSSI{name}.'_selection');
	if ($cs =~ m/^[cpqs0-7]*$/ ) {
		$copy_selection=$cs;
	} else {
		$cs =~ s/[^cpqs0-7]//g;
		$copy_selection=$cs;
		Irssi::settings_set_str($IRSSI{name}.'_selection', $cs);
	}
    my $cm= Irssi::settings_get_str($IRSSI{name}.'_method');
	my %md=(xterm=>1, xclip=>1);
	if (exists $md{$cm} ) {
		$copy_method= $cm;
	} else {
		$cm= 'xterm';
		Irssi::settings_set_str($IRSSI{name}.'_method', $cm);
		$copy_method= $cm;
	}
}

Irssi::signal_add('setup changed', \&sig_setup_changed);

Irssi::settings_add_str($IRSSI{name} ,$IRSSI{name}.'_selection', '');
Irssi::settings_add_str($IRSSI{name} ,$IRSSI{name}.'_method', 'xterm');

Irssi::command_bind($IRSSI{name}, \&cmd_copy);
Irssi::command_bind('help', \&cmd_help);

sig_setup_changed();
