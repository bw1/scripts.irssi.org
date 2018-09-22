# duckduckgo.pl is free software: you can redistribute it and/or modify
# it under the terms of the GNU Lesser General Public License as published by
# the Free Software Foundation, either version 3 of the License.
# 
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Lesser General Public License for more details.
# 
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.

use strict;
use warnings;
use Irssi;
use Mojo::Util 'url_unescape';
use Mojo::UserAgent;
use feature 'say';
use Time::HiRes;

use vars qw($VERSION %IRSSI);

$VERSION = '0.01';
%IRSSI = (
    authors	=> 'vague666',
    contact	=> 'vague666@users.noreply.github.com',
    name	=> 'ddg_async',
    description	=> 'search by duckduckgo',
    license	=> 'LGPLv3',
    url		=> 'http://scripts.irssi.org',
    changed	=> '2018-09-22',
);

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
  my $start=Time::HiRes::time();
  my $index = 1;
  my $link="http://duckduckgo.com/lite?q=";
  my $ua=Mojo::UserAgent->new;
  print "ddg: ",$link . quotemeta $data;
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
  print "ddg: ",Time::HiRes::time()-$start,"s ";
}

# vim: set sw=2 ts=2 expandtab :
