use LWP::Protocol::https;
use Mojolicious::Lite;
use Net::OAuth2::Client;

sub auth {
    my $uri = shift;
    return Net::OAuth2::Client->new(
        '<client id>',
        '<client secret>',
        site             => 'https://www.googleapis.com',
        authorize_url    => 'https://accounts.google.com/o/oauth2/auth',
        access_token_url => 'https://accounts.google.com/o/oauth2/token',
    )->web_server( redirect_uri => $uri );
}

get '/login' =>sub {
  my $self = shift;
  my $uri = auth($self->url_for('callback')->userinfo(undef)->to_abs)->authorize(
    scope => 'https://www.googleapis.com/auth/userinfo.profile',
  );
  $self->redirect_to($uri);
};

get '/callback' => sub {
  my $self = shift;
  my $code = $self->req->params->to_hash->{code};
  my $access_token = auth($self->url_for('callback')->userinfo(undef)->to_abs)->get_access_token($code);
  my $response = $access_token->get('/oauth2/v1/userinfo');
  if ( $response->is_success ) {
    # do something...
    return $self->render( json => {"hoge" => 123} );
  }
};


app->start;
__DATA__

@@ index.html.ep
<%= $user %>It works.
