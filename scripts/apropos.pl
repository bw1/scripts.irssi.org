use strict;
use vars qw($VERSION %IRSSI);

use Irssi;
use File::Fetch;
use File::Basename;
use Text::Wrap;
#use debug;

$VERSION = '0.01';
%IRSSI = (
    authors	=> 'bw1',
    contact	=> 'bw1@aol.at',
    name	=> 'apropos',
    description	=> 'tag search in markdown',
    license	=> 'Public Domain',
    url		=> 'https://scripts.irssi.org/',
    changed	=> '2020-01-02',
    modules => 'File::Fetch File::Basename Text::Wrap',
    commands=> 'apropos',
);

my $help = << "END";
%9Name%9
  $IRSSI{name}
%9Version%9
  $VERSION
%9Synopsis%9
  /$IRSSI{name} <search word>
%9description%9
  $IRSSI{description}
%9example%9
  /apropos paste
  /msg #irssi nick: see #1
%9See also%9
  https://irssi.org/documentation/
END

my $path;
my ($pcount, @pnodes);
my $pmax=3;
my $lmax=5;
my @channels;
my $data;
# ->{links}
# ->{own}
# ->{tags}
sub defaultdata {
	$data->{links}->{settings}={
		url  => 'https://irssi.org/documentation/settings/',
		src  => 'https://github.com/irssi/irssi.github.io/raw/master/documentation/settings.markdown',
		type => 'markdown',
	};
	$data->{links}->{faq}={
		url  => 'https://irssi.org/documentation/faq/',
		src  => 'https://github.com/irssi/irssi.github.io/raw/master/documentation/faq.markdown',
		type => 'markdown',
	};
	$data->{own}->{startup}=[
		{ url  => 'https://irssi.org/documentation/startup/', },
		{ url  => 'http://www.nohello.com/', },
		{ url  => 'http://www.irchelp.org/', },
	];
	$data->{own}->{channels}=[
		{ url  => ' /msg alis help list', },
		{ url  => 'http://irc.netsplit.de/channels/', },
		{ url  => ' /squery alis help list', },
	];
	$data->{own}->{irssi}=[
		{ url  => 'https://irssi.org/', },
	];
	$data->{own}->{script}=[
		{ url  => 'https://scripts.irssi.org/', },
		{ url  => 'https://github.com/shabble/irssi-docs/wiki/Guide', },
	];
	$data->{own}->{paste}=[
		{ url  => 'http://fpaste.scsys.co.uk/irssi', },
	];
	$data->{own}->{themes}=[
		{ url  => 'https://irssi-import.github.io/themes/', },
	];
	$data->{own}->{cert}=[
		{ url  => 'https://freenode.net/kb/answer/certfp', },
	];
	$data->{own}->{sasl}=[
		{ url  => 'https://freenode.net/kb/answer/sasl', },
	];
	$data->{own}->{bot}=[
		{ url  => 'script search', },
		{ url  => 'script info', },
		{ url  => 'find issue', },
		{ url  => 'syntax', },
	];
	$data->{own}->{tls}=[
		{ url  => '$ echo -e "NICK sepp3\r\nUSER sepp3 8 * :test\r\n" |gnutls-cli --no-ca-verification orwell.freenode.net:6697', },
	];
	$data->{own}->{formats}=[
		{ url  => 'https://github.com/irssi/irssi/blob/master/docs/formats.txt', },
	];
	$data->{own}->{vars}=[
		{ url  => 'https://github.com/irssi/irssi/blob/master/docs/special_vars.txt', },
	];
	$data->{own}->{register}=[
		{ url  => '/msg nickserv help register', },
		{ url  => 'https://freenode.net/kb/answer/registration', },
	];
};

sub printtag {
	my ($tag)=@_;
	if (defined $data->{tags}->{$tag}) {
		foreach my $n ( @{ $data->{tags}->{$tag} }) {
			last if ($pcount > $pmax);
			my $s=$n->{long};
			my $c=Irssi::active_win()->{width}-10;
			local $Text::Wrap::columns = $c;
			Irssi::printformat(MSGLEVEL_CLIENTCRAP, 'apropos_tag', $pcount, $tag);
			if (defined $s){
				my $long=wrap('  ', '  ', $s);
				my @l=split(/\n/,$long);
				$long=join("\n", splice(@l, 0, $lmax));
				Irssi::print($long ,MSGLEVEL_CLIENTCRAP) 
			}
			Irssi::print('%U'.$n->{url}.'%U',MSGLEVEL_CLIENTCRAP);
			push @pnodes, $n;
			$pcount++;
		}
	}
}

sub printerror {
	my ( $msg )=@_;
	Irssi::printformat(MSGLEVEL_CLIENTCRAP, 'apropos_error', $msg);
}

sub cmd {
	my ($args, $server, $witem)=@_;
	$pcount=0;
	@pnodes=();
	$args=~s/\s+$//;
	printtag( $args );
	my @l = grep { /$args/ } keys %{ $data->{tags} };
	foreach my $t ( @l ) {
		if ( $t ne $args ) {
			printtag($t);
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

sub getfile {
	my ( $fn ) = @_;
	my $ff = File::Fetch->new( uri=>$fn );
	local $File::Fetch::DEBUG=1;
	my $w = $ff->fetch( to=>$path )
		or printerror("getfile ($fn) ".$ff->error(1));
}

sub writetag {
	my ($tag, $long, $url)= @_;
	if (! exists ($data->{tags}->{$tag})) {
		$data->{tags}->{$tag}=[];
	}
	$long =~ s/%/%%/g;
	$long =~ s/\n+$//;
	$long =~ s/^\n+//;
	$long =~ s/\n\n/\n/g;
	my $node= {
		tag=>$tag,
		long=>$long,
	};
	$node->{url}= $url if (defined $url);
	push @{$data->{tags}->{$tag}}, $node;

}

sub writeowntags {
	foreach my $tag ( keys %{$data->{own}} ) {
		foreach my $node (@{$data->{own}->{$tag}}) {
			$node->{tag}= $tag;
			if (! exists ($data->{tags}->{$tag})) {
				$data->{tags}->{$tag}=[];
			}
			push @{$data->{tags}->{$tag}}, $node;
		}
	}
}

sub maketags {
	my ( $fn, $burl ) = @_;
	my $fi;
	if ( -e $fn ) {
		my $s;
		my $t;
		open($fi, '<', $fn)
			or printerror("cannot open < $fn: $!");
		while ( my $r = <$fi> ) {
			if ( $r =~ m/^#+(.*?)$/ ) {
				if (defined $t && length($s) >2) {
					writetag($t, $s, $burl.$t);
					$s='';
				}
				$t=$1;
				$t=~s/^\s+//;
				$t=~s/\s+$//;
				$t=~s/ /-/g;
				$t=~s/[:?]//g;
				$t= '#'.$t;
				$t=lc($t);
				next;
			}
			if ( $r =~ m/^\{:(#.*?)\}/ ) {
				if (defined $t) {
					writetag($t, $s, $burl.$t);
					$s='';
				}
				$t=$1;
				next;
			}
			$s .=$r if (defined $t);
		}
		writetag($t, $s, $burl.$t);
		close $fi;
	}
}

sub init {
	defaultdata();
	$path= Irssi::get_irssi_dir()."/info/";
	if (! -e $path) {
		mkdir $path;
	}
	foreach my $link ( keys %{$data->{links}} ) {
		my $src= $data->{links}->{$link}->{src};
		my $bn = basename($src);
		if (! -e $path.$bn) {
			#debug $path.$bn;
			getfile( $src );
		}
		maketags( $path.$bn, $data->{links}->{$link}->{url} );
	}
	writeowntags();
}

sub do_complete {
	my ($strings, $window, $word, $linestart, $want_space) = @_;
	return if ($linestart ne '/'.$IRSSI{name});
	@$strings = grep { m/^$word/ } keys(%{$data->{tags}});
	$$want_space = 1;
	Irssi::signal_stop;
}

sub sig_message_own_public {
	my ($server, $msg, $target)= @_;
	if ( scalar( grep { $_ eq $target } @channels ) >0 && $msg !~ m/^\s/ ) {
		for (my $c=0; $c <= $#pnodes; $c++) {
			$msg=~s/(^|\s)#$c(\s|$)/\1$pnodes[$c]->{url}\2/g;
		}
	}
	Irssi::signal_continue($server, $msg, $target);
}

sub sig_setup_changed {
	$pmax= Irssi::settings_get_int($IRSSI{name}.'_pmax');
	$lmax= Irssi::settings_get_int($IRSSI{name}.'_lmax');
	@channels= split(/\s+/,Irssi::settings_get_str($IRSSI{name}.'_channels'));
}

Irssi::theme_register([
	'apropos_tag', '{hilight $0. $1}',
	'apropos_error', '{error Error:} $0',
]);

Irssi::signal_add('setup changed', \&sig_setup_changed);
Irssi::signal_add_first('complete word',  \&do_complete);
Irssi::signal_add("message own_public", \&sig_message_own_public);

Irssi::settings_add_int($IRSSI{name} ,$IRSSI{name}.'_pmax', 3);
Irssi::settings_add_int($IRSSI{name} ,$IRSSI{name}.'_lmax', 5);
Irssi::settings_add_str($IRSSI{name} ,$IRSSI{name}.'_channels', '#irssi');

Irssi::command_bind($IRSSI{name}, \&cmd);
Irssi::command_bind('help', \&cmd_help);

sig_setup_changed();
init();
