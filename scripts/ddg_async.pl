use Irssi;
use strict;
use warnings;
use Mojo::Util 'url_unescape';
use Mojo::UserAgent;
use feature 'say';

Irssi::command_bind('ddg', 'cmd_wrapper');
Irssi::signal_add('message public', 'sig_wrapper');

sub sig_wrapper {
  my ($server, $msg, undef, undef, $target) = @_;
  ddg($msg, $server->{tag}, $target) if $msg =~ s/^!ddg\s+(.+)/$1/;
}

sub cmd_wrapper {
  my ($data, $server, $witem) = @_;
  ddg($data, $server->{tag}, $witem->{visible_name} || $witem->window->{name});
}

sub ddg {
  my ($data, $tag, $target) = @_;
  my $index = 1;
  my $link="http://duckduckgo.com/lite?q=";
  my $ua=Mojo::UserAgent->new;
  $ua->max_redirects(10)->max_connections(0)->get_p($link . quotemeta $data)->then(sub {
    my $tx = shift;
    my $server = Irssi::server_find_tag($tag);
    return unless $server;

    my $witem = $server->window_item_find($target);
    return unless $witem;

    my $res = $tx->res->dom->find('tr:not(@class="result-sponsored") td[valign=top]')->slice(0..3)->map(sub {
      my $tr    = $_->parent;
      my $link  = url_unescape Mojo::URL->new($tr->at('td a.result-link')->attr('href'))->query->param('uddg');
      my $topic = $tr->next->at('td.result-snippet')->text =~ s/^\s*|\s*$//grm;
      $topic =~ s/\s{2,}/ /g;
      sprintf("%d. %s - %.40s", $index++, $link, $topic);
    })->slice(0 .. 3)->join(', ');
    $witem->command("say $res");
  })->catch(sub {
    my $err = shift;
    my $server = Irssi::server_find_tag($tag);
    return unless $server;

    my $win = $server->window_find_item($target);
    return unless $win;
    $win->print("Connection error: $err");
  })->wait;
}
