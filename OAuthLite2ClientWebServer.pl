use JSON;
use Mojolicious::Lite;
use OAuth::Lite2::Client::WebServer;


my $app = app;


sub config {
  open (my $fh, '<', './config.json') || die "can't open $!";
  my $data;
  eval{
    local $/ = undef;
    my $json_text = <$fh>;
    close $fh;
    $data = decode_json($json_text);
  };
  if ($@) {
    print STDERR ("invalid json text: $@\n");
    exit 1;
  }
  return $data;
};

my $client = OAuth::Lite2::Client::WebServer->new(
  id => config->{client_id},
  secret => config->{client_secret},
  authorize_uri => 'https://accounts.google.com/o/oauth2/auth',
  access_token_uri => 'https://accounts.google.com/o/oauth2/token',
);

sub start_authorize {
  my $app = shift;
  my $redirect_uri = $client->uri_to_redirect(
    redirect_uri => $app->url_for('callback')->userinfo(undef)->to_abs,
    scope => 'profile',
  );
  $app->redirect_to($redirect_uri);
}

get '/' => sub {
  my $self = shift;
  if ( ! $self->session->{authed} ) {
    $self->redirect_to('login');
  }
  return $self->render(
    'index',
    'params' => {
      'user' =>  'nabetama',
      'authed' => $self->session->{authed},
    }
  );
};

get '/login' =>sub {
  my $self = shift;
  start_authorize($self);
};

get '/callback' => sub {
  my $self = shift;
  my $code = $self->req->params->to_hash->{code};

  my $access_token = $client->get_access_token(
    code => $code,
    redirect_uri => $self->url_for('callback')->userinfo(undef)->to_abs,
  ) or $self->redirect_to("401", "status" => 401);
  $self->session(
    access_token => $access_token,
    expires_at   => time() + $access_token->expires_in,
    access_token => $access_token->refresh_token,
  );
};

app->start;
__DATA__

@@ index.html.ep
<%
my $user = stash('params');
%>
<%= $user->{user} %> Login.


@@ login.html.ep
<%
my $user = stash('params');
%>
<%= $user->{user} %> Login.

@@ 401.html.ep
401 Client Error.

@@ callback.html.ep
callback
