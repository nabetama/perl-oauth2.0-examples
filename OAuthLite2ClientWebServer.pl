use JSON;
use Mojolicious::Lite;
use OAuth::Lite2::Client::WebServer;
use LWP::UserAgent;
use URI;


my $g_app = app;


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
    scope => 'profile email',
    extra => {approval_prompt=>'force', access_type=>'offline'}, # Maybe, only Google OAuth2.0.
  );
  $app->redirect_to($redirect_uri);
}

sub get_token_info {
  my $access_token = shift;
  my $ua = LWP::UserAgent->new;
  my $params = { access_token => $access_token };
  my $uri = URI->new('https://www.googleapis.com/oauth2/v1/tokeninfo');
  $uri->query_form($params);

  $ua->timeout(3);
  $ua->env_proxy;
  my $response = $ua->get($uri);
  if ($response->is_success) {
    return decode_json($response->content);
  }
  else {
    $g_app->log->info($response->content);
    die $response->status_line;
  }
};

sub set_token_info {
  my ($app, $code) = @_;
  my $t = $client->get_access_token(
    code => $code,
    redirect_uri => $app->url_for('callback')->userinfo(undef)->to_abs,
  ) or return '';

  if ( !$t ) {
    return 1;
  }

  $app->session(
    access_token  => $t->access_token,
    expires_at    => time() + $t->expires_in,
    refresh_token => $t->refresh_token,
    scope         => $t->scope,
    token_info    => get_token_info($t->access_token),
  );
};

sub is_access_to_callback {
  my $code = shift;
  if ($code) {
    return 1;
  }
  return 0;
}

sub is_expire {
  my $app = shift;
  if ( $app->session('expires_at') < time()) {
    return 1;
  }
  return 0;
}

sub refresh_access_token {
  my $app = shift;
  my $t = $client->refresh_access_token(
    refresh_token => $app->session('refresh_token'),
  ) or return undef;
  $app->session(
    access_token  => $t->access_token,
    expires_at    => time() + $t->expires_in,
    token_info    => get_token_info($t->access_token),
  );
  return 1;
};

under sub {
  my $self = shift;
  my $token_info = $self->session->{token_info};
  if ( ! $token_info ) {
    my $code = $self->req->params->to_hash->{code};
    if ( is_access_to_callback($code) ) {
      set_token_info($self, $code);
    }
    $self->redirect_to('login');
  }
  if (is_expire($self)) {
    refresh_access_token($self);
  }
  return 1;
};

get '/' => sub {
  my $self = shift;
  return $self->render(
    'index',
    'params' => {
      'user' =>  $self->session->{token_info}->{email},
    }
  );
};

get '/login' =>sub {
  my $self = shift;
  start_authorize($self);
};

get '/callback' => sub {
  my $self = shift;
  $self->redirect_to('/');
  return 1;
};

get '/logout' => sub {
  my $self = shift;
  $self->session(expires => 1);
  return 1;
};

app->start;
__DATA__

@@ index.html.ep
<p>index.html</p>
<% my $userinfo = session 'token_info'; %>
<%=  $userinfo->{email} %>

Expires_at
<%= session 'expires_at' %>
Refresh_token
<%= session 'refresh_token' %>


@@logout.html.ep
<p>logout.html</p>
Bye!
<% my $userinfo = session 'token_info'; %>
<%=  $userinfo->{email} %>
<p>

Expires_at
<%= session 'expires_at' %>
Refresh_token
<%= session 'refresh_token' %>
