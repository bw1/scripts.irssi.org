use strict;
use warnings;
use vars qw($VERSION %IRSSI);

use Irssi;
use File::Fetch;
use File::Basename;
use Text::Wrap;
use CPAN::Meta::YAML;
use Storable qw/dclone/;

#use debug;

$VERSION = '0.02';
%IRSSI = (
    authors	=> 'bw1',
    contact	=> 'bw1@aol.at',
    name	=> 'apropos',
    description	=> 'tag search in markdown',
    license	=> 'Public Domain',
    url		=> 'https://scripts.irssi.org/',
    changed	=> '2022-09-18',
    modules => 'File::Fetch File::Basename Text::Wrap CPAN::Meta::YAML',
    commands=> 'apropos',
);

my $help = << "END";
%9Name%9
  $IRSSI{name}
%9Version%9
  $VERSION
%9Synopsis%9
  /$IRSSI{name} <search word>
  /$IRSSI{name} {-h|-d|-i|-n}
  /$IRSSI{name} -p <num>
%9description%9
  $IRSSI{description}
%9options%9
  -h    help
  -d    dump
  -i    init (reload config)
  -n    next
  -p    print (print out the node in long)
%9example%9
  /apropos paste
  /msg #irssi nick: see #1
%9See also%9
  https://irssi.org/documentation/
END

my $path;
my ($pmax, $lmax, @channels, $query) ;
my $fnconfig='config.yaml';
my (@results, $resp);
my $data;
# ->{links}
#   ->{type}
#   		md1  markdown tags from header lines
#   		md1s markdown tags from (.*)=
# ->{own}
# ->{tags}
# ->{last}

sub defaultdata {
	$data->{links}->{settings}={
		#url  => 'https://irssi.org/documentation/settings/',
		#src  => 'https://github.com/irssi/irssi.github.io/raw/master/documentation/settings.markdown',
		#src  => 'https://raw.githubusercontent.com/irssi/irssi.github.io/master/documentation/settings.markdown',
		url  => 'https://irssi.org/documentation/settings/',
		src  => 'https://github.com/irssi/irssi.github.io/raw/main/sphinx/documentation/settings.md',
		type => 'md1s',
	};
	$data->{links}->{faq}={
		#src  => 'https://github.com/irssi/irssi.github.io/raw/master/documentation/faq.markdown',
		#src  => 'https://raw.githubusercontent.com/irssi/irssi.github.io/master/documentation/faq.markdown',
		url  => 'https://irssi.org/documentation/qna/',
		#src  => 'https://github.com/irssi/irssi.github.io/raw/main/sphinx/documentation/qna/', # !!
		src =>  'https://api.github.com/repos/irssi/irssi.github.io/contents/sphinx/documentation/qna',
		type => 'dir1',
	};
	$data->{own}->{startup}=[
		{ url  => 'https://irssi.org/New-users/', },
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
		{ url  => 'https://github.com/irssi/irssi/raw/master/docs/perl.txt', },
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
	my ($num, $n, $maxl)=@_;
	$maxl= $lmax if (!defined $maxl);
	if (defined $n) {
		my $s=$n->{long};
		my $c=Irssi::active_win()->{width}-10;
		local $Text::Wrap::columns = $c;
		Irssi::printformat(MSGLEVEL_CLIENTCRAP, 'apropos_tag', $num, $n->{tag});
		if (defined $s){
			my $long=wrap('  ', '  ', $s);
			my @l=split(/\n/,$long);
			$long=join("\n", splice(@l, 0, $maxl));
			Irssi::print($long ,MSGLEVEL_CLIENTCRAP) 
		}
		Irssi::print('%U'.$n->{url}.'%U',MSGLEVEL_CLIENTCRAP);
	}
}

sub printerror {
	my ( $msg )=@_;
	Irssi::printformat(MSGLEVEL_CLIENTCRAP, 'apropos_error', $msg);
}

sub cmd {
	my ($args, $server, $witem)=@_;
	my ($opt, $arg) = Irssi::command_parse_options($IRSSI{'name'}, $args);
	$arg=~s/\s+$//;
	if (exists $opt->{h}) {
		Irssi::print($help, MSGLEVEL_CLIENTCRAP);
	} elsif ( exists $opt->{d} ){
		cmd_dump();
	} elsif ( exists $opt->{i} ){
		init()
	} elsif ( exists $opt->{n} ){
		cmd_next();
	} elsif ( exists $opt->{p} ){
		printtag($arg, $results[$arg], 70);
	} else {
		cmd_search( $arg )
	}
}

sub cmd_search {
	my ( $arg )= @_;
	@results=();
    my %def=();
    # equal
	foreach my $n (@{$data->{tags}->{$arg}}) {
		push @results, $n;
        $def{$n->{url}}=0;
	}
    # last match
	my @l = sort grep { /$arg/ } keys %{ $data->{last} };
	foreach my $t ( @l ) {
		if ( $t ne $arg ) {
			foreach my $n (@{$data->{tags}->{$t}}) {
				push @results, $n;
                $def{$n->{url}}=0;
			}
		}
	}
    # remaining
	@l = sort grep { /$arg/ } keys %{ $data->{tags} };
	foreach my $t ( @l ) {
        foreach my $n (@{$data->{tags}->{$t}}) {
            if ( !exists $def{$n->{url}} ) {
                push @results, $n;
            }
        }
	}
	my $c=0;
	$resp=0;
	foreach my $n (@results) {
		printtag($c, $n);
		$c++;
		last if ($c+1 > $pmax );
	}
}

sub cmd_next {
	$resp += $pmax;
	for (my $c= $resp; $c < $resp + $pmax; $c++) {
		printtag($c, $results[$c]);
	}
}

sub cmd_dump {
	my $y= CPAN::Meta::YAML->new($data->{own});
	Irssi::print($y->write_string, MSGLEVEL_CLIENTCRAP);
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
	my $w = $ff->fetch( to=>$path )
		or printerror("getfile ($fn) ".$ff->error(1));
}

sub getyamlfile {
	my ( $fn )=@_;
	if ( -e $fn ) {
		my $y= CPAN::Meta::YAML->read($fn);
		return $y->[0];
	}
}

sub putyamlfile {
	my ( $fn, $r )=@_;
	my $y= CPAN::Meta::YAML->new($r);
	$y->write( $fn );
}

sub writetag {
	my ($tag, $long, $url)= @_;
	return unless (defined $long && length($long) >2 );
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

sub maketags_md1 {
	my ( $fn, $burl ) = @_;
	my $fi;
	if ( -e $fn ) {
		my $s;
		my $t;
		open($fi, '<', $fn)
			or printerror("cannot open < $fn: $!");
		while ( my $r = <$fi> ) {
			# section with mark
			if ( $r =~ m/^#+.*?{(.*?)}$/ ) {
				if (defined $t && length($s) >2) {
					writetag($t, $s, $burl.$t);
					$s=undef;
				}
				$t=$1;
				next;
			}
			# section
			if ( $r =~ m/^#+(.*?)$/ ) {
				if (defined $t && length($s) >2) {
					writetag($t, $s, $burl.$t);
					$s=undef;
				}
				$t=$1;
				$t=~s/^\s+//;
				$t=~s/\s+$//;
				$t=~s/ /-/g;
				$t=~s#/##g;
				$t=~s/[:!?,.'`"\(\)]//g;
				$t= '#'.$t;
				$t=lc($t);
				next;
			}
			# mark only
			if ( $r =~ m/^\{:(#.*?)\}/ ) {
				if (defined $t && length($s) >2) {
					writetag($t, $s, $burl.$t);
					$s=undef;
				}
				$t=$1;
				next;
			}
			$s .=$r if (defined $t);
		}
		if (defined $t && length($s) >2) {
			writetag($t, $s, $burl.$t);
		}
		close $fi;
	}
}

sub maketags_md1s {
	my ( $fn, $burl ) = @_;
	my $fi;
	return unless ( -e $fn ) ;
	my $s;
	my $t;
	my $u;
	open($fi, '<', $fn)
		or printerror("cannot open < $fn: $!");
	while ( my $r = <$fi> ) {
		if ($r =~ m/^\((.*)\)=/) {
			if (defined $t && defined $s && length($s) >2 ) {
				writetag($t, $s, $u);
				$t=undef;
				$s=undef;
				$u=undef
			}
			$t= $1;
			$u= $1;
			$u=~ s/_/-/g;
			$u="$burl\#$u";
		} elsif ( $r =~ m/`(.*?)` \*\*`(.*?)`\*\*/ ) {
			$s= "$1 $2\n";
		} elsif ( $r =~ m/^: (.*)/ ) {
			$s.=$1;
		}
	}
	writetag($t, $s, $u);
	close $fi;
}

sub maketags_dir1 {
	my ( $n ) = @_;
	my $fi;
}

sub init {
	$path= Irssi::get_irssi_dir()."/apropos/";
	if ( -e $path.$fnconfig ) {
		$data=getyamlfile($path.$fnconfig);
	} else {
		defaultdata();
	}
	if (! -e $path) {
		mkdir $path;
	}
	foreach my $link ( keys %{$data->{links}} ) {
		my $type=$data->{links}->{$link}->{type};
		my $url=$data->{links}->{$link}->{url};
		my $src= $data->{links}->{$link}->{src};
		if ( $type =~ m/^md/ ) {
			my $bn = basename($src);
			if (! -e $path.$bn) {
				getfile( $src );
			}
			if ( $type eq 'md1' ) {
				maketags_md1( $path.$bn, $url );
			} elsif ( $type eq 'md1s' ) {
				maketags_md1s( $path.$bn, $url );
			} 
		} else {
			if ( $type eq 'dir1' ) {
				maketags_dir1($data->{links}->{$link});
			}
		}
	}
	writeowntags();
	Irssi::print("Tags:".scalar keys %{$data->{tags}} , MSGLEVEL_CLIENTCRAP);
}

sub do_complete {
	my ($strings, $window, $word, $linestart, $want_space) = @_;
	return if ($linestart ne '/'.$IRSSI{name});
	@$strings = grep { m/^$word/ } keys(%{$data->{tags}});
	$$want_space = 1;
	Irssi::signal_stop;
}

sub putlast {
    my ($node)=@_;
    my $n= dclone $node;
    if (!exists $data->{last}->{$n->{tag}}) {
        $data->{last}->{$n->{tag}}=[];
    }
    my $u= $n->{url};
    foreach my $p (@{ $data->{last}->{$n->{tag}} }) {
        return if ($u eq $p->{url});
    }
    push @{$data->{last}->{$n->{tag}}},$n;
}

sub sig_send_text {
	my ($msg, $server, $witem) = @_;
	my $omsg= $msg;
	if ( (scalar( grep { $_ eq $witem->{name} } @channels ) >0 ||
			($witem->{type} eq 'QUERY' && $query))
			&& $msg !~ m/^\s/ ) {
		for (my $c=0; $c <= $#results; $c++) {
			if ($msg=~s/(^|\s)#$c(\s|$)/$1$results[$c]->{url}$2/g) {
				putlast($results[$c]);
			}
		}
	}
	if ( $omsg ne $msg ) {
		Irssi::signal_continue($msg, $server, $witem);
	}
}

sub sig_setup_changed {
	$pmax= Irssi::settings_get_int($IRSSI{name}.'_pmax');
	$lmax= Irssi::settings_get_int($IRSSI{name}.'_lmax');
	@channels= split(/\s+/,Irssi::settings_get_str($IRSSI{name}.'_channels'));
	$query=Irssi::settings_get_bool($IRSSI{name}.'_query');
}

sub UNLOAD {
	delete $data->{tags};
	putyamlfile( $path.$fnconfig, $data);
}

Irssi::theme_register([
	'apropos_tag', '{hilight $0. $1}',
	'apropos_error', '{error Error:} $0',
]);

Irssi::signal_add('setup changed', \&sig_setup_changed);
Irssi::signal_add_first('complete word',  \&do_complete);
Irssi::signal_add('send text', \&sig_send_text);

Irssi::settings_add_int($IRSSI{name} ,$IRSSI{name}.'_pmax', 3);
Irssi::settings_add_int($IRSSI{name} ,$IRSSI{name}.'_lmax', 5);
Irssi::settings_add_str($IRSSI{name} ,$IRSSI{name}.'_channels', '#irssi');
Irssi::settings_add_bool($IRSSI{name} ,$IRSSI{name}.'_query', 0);

Irssi::command_bind($IRSSI{name}, \&cmd);
Irssi::command_bind('help', \&cmd_help);
Irssi::command_set_options($IRSSI{name},"h d i n p");

sig_setup_changed();
init();
