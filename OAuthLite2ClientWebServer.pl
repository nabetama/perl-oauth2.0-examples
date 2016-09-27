use Mojolicious::Lite;
use OAuth::Lite2::Client::WebServer;


my $client = OAuth::Lite2::Client::WebServer->new(
);

app->start;
__DATA__

@@ index.html.ep
<%= $user %>It works.
