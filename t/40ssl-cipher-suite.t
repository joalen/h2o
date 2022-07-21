use strict;
use warnings;
use File::Temp qw(tempdir);
use Net::EmptyPort qw(check_port empty_port);
use Test::More;
use t::Util;

plan skip_all => "could not find openssl (1)"
    unless prog_exists("openssl");
plan skip_all => "no support for chacha20poly1305"
    unless grep { /^TLS_CHACHA20_POLY1305_SHA256$/m } split /:/, `openssl ciphers`;

my $tempdir = tempdir(CLEANUP => 1);
my $port = empty_port();

# spawn server that only accepts AES128-SHA (tls1.2), or CHACHA20POLY1305 -> AES128GCMSHA256 (tls1.3), see if appropriate cipher-
# suites are selected
subtest "select-cipher" => sub {
    my $server = spawn_h2o_raw(<< "EOT", [ $port ]);
listen:
  host: 127.0.0.1
  port: $port
  ssl:
    key-file: examples/h2o/server.key
    certificate-file: examples/h2o/server.crt
    cipher-suite: AES128-SHA
    cipher-suite-tls1.3: [TLS_CHACHA20_POLY1305_SHA256, TLS_AES_128_GCM_SHA256]
    cipher-preference: server
    max-version: TLSv1.3
hosts:
  default:
    paths:
      /:
        file.dir: @{[ DOC_ROOT ]}
EOT

    subtest "tls1.2" => sub {
        # connect to the server with AES256-SHA as the first choice, and check that AES128-SHA was selected
        my $log = run_openssl_client({ host => "127.0.0.1", port => $port, opts => "-tls1_2 -cipher AES256-SHA:AES128-SHA" });
        like $log, qr/^\s*Cipher\s*:\s*AES128-SHA\s*$/m;

        # connect to the server with AES256-SHA as the only choice, and check that handshake failure is returned
        $log = run_openssl_client({ host => "127.0.0.1", port => $port, opts => "-tls1_2 -cipher AES256-SHA" });
        like $log, qr/alert handshake failure/m; # "handshake failure" the official name for TLS alert 40
    };

    subtest "tls1.3" => sub {
        plan skip_all => "openssl does not support tls 1.3"
            unless openssl_supports_tls13();
        # TLS 1.3 test
        my $log = run_openssl_client({ host => "127.0.0.1", port => $port, opts => "-tls1_3 -ciphersuites TLS_AES_128_GCM_SHA256:TLS_CHACHA20_POLY1305_SHA256" });
        like $log, qr/^\s*Cipher\s*:\s*TLS_CHACHA20_POLY1305_SHA256\s*$/m;

        $log = run_openssl_client({ host => "127.0.0.1", port => $port, opts => "-tls1_3 -ciphersuites TLS_AES_256_GCM_SHA384" });
        unlike $log, qr/TLS_AES_256_GCM_SHA384/m;
    };
};

subtest "tls12-on-picotls" => sub {
    plan skip_all => 'curl not found'
        unless prog_exists('curl');

    # mapping of TLS 1.2 cipher suite => TLS 1.3 cipher-suite & bits (do we want to bother emitting TLS 1.2 cipher suites?)
    my %ciphers = (
        "ECDHE-RSA-AES128-GCM-SHA256" => [ "AES128-GCM", 128 ],
        "ECDHE-RSA-AES256-GCM-SHA384" => [ "AES256-GCM", 256 ],
        "ECDHE-RSA-CHACHA20-POLY1305" => [ "CHACHA20-POLY1305", 256 ],
    );

    my $server = spawn_h2o_raw(<< "EOT", [ $port ]);
listen:
  host: 127.0.0.1
  port: $port
  ssl:
    key-file: examples/h2o/server.key
    certificate-file: examples/h2o/server.crt
    cipher-suite: "@{[ join q(:), sort keys %ciphers ]}"
    cipher-preference: server
    max-version: TLSv1.3
hosts:
  default:
    paths:
      /:
        file.dir: @{[ DOC_ROOT ]}
access-log:
  path: $tempdir/access_log
  format: "%{ssl.protocol-version}x %{ssl.cipher}x %{ssl.cipher-bits}x"
EOT

    open my $logfh, "<", "$tempdir/access_log"
        or die "failed to open $tempdir/access_log:$!";

    for my $cipher (sort keys %ciphers) {
        subtest $cipher => sub {
            plan skip_all => "$cipher is unavailable"
                unless do { `openssl ciphers | fgrep $cipher`; $? == 0 };
            my $output = `curl --silent -k --tls-max 1.2 --ciphers $cipher https://127.0.0.1:$port/`;
            is $output, "hello\n", "output";
            sleep 1; # make sure log is emitted
            sysread $logfh, my $log, 4096; # use sysread to avoid buffering that prevents us from reading what's being appended
            like $log, qr/^TLSv1\.2 $ciphers{$cipher}->[0] $ciphers{$cipher}->[1]$/m, "log";
        };
    }
};

done_testing;
