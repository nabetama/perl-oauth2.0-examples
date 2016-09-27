use Mojolicious::Lite;
use Mojolicious::Plugin::OAuth2;

plugin 'OAuth2' => {
  google => {
    key => '<client key>',
    secret => '<client secret>',
  },
};

get "/callback" => sub {
  my $c = shift;
  $c->delay(
    sub {
      my $delay = shift;
      my $args = {redirect_uri => $c->url_for('callback')->userinfo(undef)->to_abs};
      $c->oauth2->get_token(google => $args, $delay->begin, scope => 'profile');
    },
    sub {
      my ($delay, $err, $data) = @_;
      return $c->render("callback", error => $err) unless $data->{access_token};
      return $c->session(token => $c->redirect_to('profile'));
    },
  );
};

get "/profile" => sub {
    my $c = shift;
    return $c->render('profile');
};

app->start;
__DATA__

@@ profile.html.ep
It works.
