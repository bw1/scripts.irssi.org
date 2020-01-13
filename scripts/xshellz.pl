use strict;
use vars qw($VERSION %IRSSI);
use POSIX;

use Irssi;
use Irssi::TextUI;
use CPAN::Meta::YAML;

$VERSION = '0.01';
%IRSSI = (
    authors	=> 'senn',
    contact	=> 'senn@xshellz.com',
    name	=> 'xshellz',
    description	=> 'Helper for xshellz',
    license	=> 'Public Domain',
    url		=> '',
    changed	=> '2019-12-18',
    modules => '',
    commands=> 'xshellz',
);

my $help = << "END";
%9Name%9
  $IRSSI{name}
%9Version%9
  $VERSION
%9description%9
  $IRSSI{description}
  add the statusbar item
    /STATUSBAR window ADD xshellz_credit
%9See also%9
  null.pl
  https://perldoc.perl.org/perl.html
  https://github.com/irssi/irssi/blob/master/docs/perl.txt
  https://github.com/irssi/irssi/blob/master/docs/signals.txt
  https://github.com/irssi/irssi/blob/master/docs/formats.txt
END

my $test_str;
my $data;

my $data->{last}=time();

sub load {
	my $p= Irssi::get_irssi_dir();
	my $f= '/xshellz.yml';
	if ( -e $p.$f ) {
		my $yml= CPAN::Meta::YAML->read($p.$f)
			or Irssi::print(CPAN::Meta::YAML->errstr, MSGLEVEL_CLIENTCRAP);
		$data=$yml->[0];
	}
}

sub save {
	my $p= Irssi::get_irssi_dir();
	my $f= '/xshellz.yml';
	my $yml= CPAN::Meta::YAML->new($data);
	$yml->write($p.$f)
		or Irssi::print(CPAN::Meta::YAML->errstr, MSGLEVEL_CLIENTCRAP);
}

sub out {
	my ($witem, @str)= @_;
	my $s= join '', @str;
	if (defined $witem) {
		$witem->print($s, MSGLEVEL_CLIENTCRAP );
	} else {
		Irssi::print($s, MSGLEVEL_CLIENTCRAP);
	}
}

sub rest {
	my $n=$data->{last} + 2*7*24*60*60 - time();
	my $sa=$n;
	$n= $n/60/60/24;
	my $d=int($n);
	$n -= $d;
	$n= $n*24;
	my $h=int($n);
	$n -= $h;
	$n= $n*60;
	my $m=int($n);
	return wantarray ? ($d, $h, $m) : $sa;
}

sub cmd {
	my ($args, $server, $witem)=@_;
	$args =~ s/^\s+//;
	my @args= split /\s+/,$args;
	my $a= shift @args;
	if ($a eq 'keep') {
		$server->command('/^msg -Freenode xinfo !keep senn');
		#$server->command('/echo xinfo !keep senn');
		$data->{last}= time();
		save();
	}
	if ($a eq 'stat') {
		my ($d, $h, $m)= rest();
		out( $witem, "Restzeit: ${d}d ${h}h ${m}m");
	}
	if ($a eq 'save') {
		save();
	}
	if ($a eq 'start') {
		$data->{last}= time();
		save();
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

sub sig_update {
	Irssi::statusbar_items_redraw("xshellz_credit");
}

sub sig_setup_changed {
	$test_str= Irssi::settings_get_str($IRSSI{name}.'_test_str');
}

sub sb_xshellz_credit {
	my ($sb_item, $get_size_only) = @_;
	my ($d, $h, $m)= rest();
	my $sb = "${d}d ${h}h ${m}m";
	$sb_item->default_handler($get_size_only, "{sb $sb}", '', 0);
}

Irssi::statusbar_item_register ('xshellz_credit', 0, 'sb_xshellz_credit');

my $time_tag= Irssi::timeout_add(1*60*1000, \&sig_update, '');

Irssi::theme_register([
	'example_theme', '{hilight $0} $1 {error $2}',
]);

Irssi::signal_add('setup changed', \&sig_setup_changed);

Irssi::settings_add_str($IRSSI{name} ,$IRSSI{name}.'_test_str', 'hello world!');

Irssi::command_bind($IRSSI{name}, \&cmd);
foreach ( qw/keep stat save start/) {
	Irssi::command_bind($IRSSI{name}." ".$_, \&cmd);
}

Irssi::command_bind('help', \&cmd_help);

sig_setup_changed();
load();
