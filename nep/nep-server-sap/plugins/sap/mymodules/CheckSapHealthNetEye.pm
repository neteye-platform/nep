# CheckSapHealthNetEye.pm - extensions (my-modes) for check_sap_health
#
# Installation: copy into the directory passed with --with-mymodules-dyn-dir
#               (e.g. /neteye/shared/monitoring/plugins/sap/mymodules)
#
# Modes:
#   --mode my-updates   update requests (VBHDR, SM13) older than --lookback seconds (default 86400)
#   --mode my-locks     lock entries (ENQUEUE_READ, SM12) older than --lookback seconds (default 86400)
#   --mode my-queues    qRFC queues (TRFCQIN/TRFCQOUT, SMQ1/SMQ2) in error state
#
# Thresholds: default --warning 0 --critical 0 (CRITICAL as soon as one object is found),
#             override with --warning/--critical or --warningx/--criticalx <metric>=<threshold>
#
# 16.11.2026  initial version
#

package NetEyeSap;
use strict;
use Time::Local;

# NW RFC SDK 7.50 + sapnwrfc 0.37: function descriptions belong to the SDK cache
# and must not be destroyed (otherwise segfault on the second lookup of the same function).
# Same fix as in the patched check_sap_health, repeated here in case the plugin is not patched.
{ no warnings qw(redefine once); *SAPNW::RFC::FunctionDescriptor::DESTROY = sub {}; }

# split a WHERE condition into RFC_READ_TABLE OPTIONS lines (max 72 chars)
sub options {
  my ($condition) = @_;
  my @options = ();
  while ($condition ne "") {
    if ($condition =~ /^(.{1,70}(\s|$))/s) {
      push(@options, { 'TEXT' => $1 });
      $condition = substr($condition, length($1));
    } else {
      push(@options, { 'TEXT' => substr($condition, 0, 70) });
      $condition = substr($condition, 70);
    }
  }
  return \@options;
}

# RFC_READ_TABLE without delimiter, values are cut using OFFSET/LENGTH returned in FIELDS
# (independent of the column order returned by newer SAP releases)
sub read_table {
  my ($session, $table, $fields, $where, $rowcount) = @_;
  my $fl = $session->function_lookup("RFC_READ_TABLE");
  my $fc = $fl->create_function_call;
  $fc->QUERY_TABLE($table);
  $fc->ROWCOUNT($rowcount) if $rowcount;
  $fc->OPTIONS(options($where)) if $where;
  $fc->FIELDS([map { { 'FIELDNAME' => $_ } } @{$fields}]);
  $fc->invoke;
  my @layout = map {
    { name => strip($_->{FIELDNAME}), offset => $_->{OFFSET} + 0, length => $_->{LENGTH} + 0 }
  } @{$fc->FIELDS};
  my @rows = ();
  foreach my $line (@{$fc->DATA}) {
    my $wa = $line->{WA};
    my %row = ();
    foreach my $f (@layout) {
      my $value = length($wa) > $f->{offset} ? substr($wa, $f->{offset}, $f->{length}) : "";
      $row{$f->{name}} = strip($value);
    }
    push(@rows, \%row);
  }
  return \@rows;
}

sub strip {
  my ($v) = @_;
  $v = "" if ! defined $v;
  $v =~ s/^\s+//;
  $v =~ s/\s+$//;
  return $v;
}

# ABAP date (YYYYMMDD) + time (HHMMSS) -> epoch, undef if not valid
sub epoch {
  my ($date, $time) = @_;
  return undef if ! $date || $date !~ /^(\d{4})(\d{2})(\d{2})$/ || $date eq "00000000";
  my ($y, $m, $d) = ($1, $2, $3);
  $time = "000000" if ! $time || $time !~ /^\d{6}$/;
  $time =~ /^(\d{2})(\d{2})(\d{2})$/;
  my $epoch = eval { timelocal($3, $2, $1, $d, $m - 1, $y) };
  return $@ ? undef : $epoch;
}

sub age_text {
  my ($sec) = @_;
  return "?" if ! defined $sec;
  my $d = int($sec / 86400);
  my $h = int(($sec % 86400) / 3600);
  my $m = int(($sec % 3600) / 60);
  return $d ? sprintf("%dd %02dh", $d, $h) : sprintf("%dh %02dm", $h, $m);
}

sub clean_error {
  my ($message) = @_;
  $message =~ s/[^[:ascii:]]//g;
  $message =~ s/\s+at \/\S+ line \d+.*//s;
  $message =~ s/\s+$//;
  return $message;
}

# common evaluation: thresholds, message and detail lines
sub evaluate {
  my ($self, %p) = @_;
  $self->set_thresholds(metric => $p{metric}, warning => 0, critical => 0);
  my $level = $self->check_thresholds(metric => $p{metric}, value => $p{value});
  $self->add_message($level, $p{summary});
  if ($level) {
    my $max = 10;
    my @details = @{$p{details}};
    foreach (@details[0 .. ($#details < $max - 1 ? $#details : $max - 1)]) {
      $self->add_message($level, $_);
    }
    $self->add_message($level, sprintf("... and %d more", scalar(@details) - $max)) if @details > $max;
  }
  $self->add_perfdata(label => $p{metric}, value => $p{value});
}


#############################################################################
# --mode my-updates
#   counts update requests in VBHDR (all clients) older than --lookback seconds
#   --name  optional regexp on client
#############################################################################
package MyUpdates;
our @ISA = qw(Classes::SAP::Netweaver);
use strict;

sub init {
  my ($self) = @_;
  eval {
    my $maxage = $self->opts->lookback || 86400;
    my $now = time;
    my ($date, $time) = $self->epoch_to_abap_date_and_time($now - $maxage);
    my $where = sprintf "VBDATE < '%s%s'", $date, $time;
    my $rows;
    # VBRC (INT4) is not readable on every release with RFC_READ_TABLE -> retry without it
    eval {
      $rows = NetEyeSap::read_table($self->session, "VBHDR",
          [qw(VBKEY VBMANDT VBUSR VBTCODE VBDATE VBRC)], $where, 10000);
    };
    if ($@) {
      $self->debug("VBHDR with VBRC failed: $@");
      $rows = NetEyeSap::read_table($self->session, "VBHDR",
          [qw(VBKEY VBMANDT VBUSR VBTCODE VBDATE)], $where, 10000);
    }
    my $client_re = $self->opts->name;
    my @updates = ();
    foreach my $r (@{$rows}) {
      next if $client_re && $r->{VBMANDT} !~ /$client_re/;
      my ($d, $t) = $r->{VBDATE} =~ /^(\d{8})(\d{6})/;
      $r->{epoch} = NetEyeSap::epoch($d, $t);
      $r->{age} = defined $r->{epoch} ? $now - $r->{epoch} : undef;
      push(@updates, $r);
    }
    @updates = sort { ($b->{age} || 0) <=> ($a->{age} || 0) } @updates;
    my $errors = scalar(grep { defined $_->{VBRC} && $_->{VBRC} =~ /^-?\d+$/ && $_->{VBRC} != 0 } @updates);
    my $oldest = @updates ? $updates[0]->{age} : 0;
    my $summary = @updates ?
        sprintf("%d update request(s) older than %s%s, oldest %s",
            scalar(@updates), NetEyeSap::age_text($maxage),
            (exists $updates[0]->{VBRC} ? sprintf(" (%d with error)", $errors) : ""),
            NetEyeSap::age_text($oldest)) :
        sprintf("no update requests older than %s", NetEyeSap::age_text($maxage));
    NetEyeSap::evaluate($self,
        metric => 'old_updates', value => scalar(@updates), summary => $summary,
        details => [map {
          sprintf "client %s user %s tcode %s age %s%s", $_->{VBMANDT}, $_->{VBUSR},
              ($_->{VBTCODE} || '-'), NetEyeSap::age_text($_->{age}),
              (exists $_->{VBRC} ? " rc ".$_->{VBRC} : "");
        } @updates]);
    $self->add_perfdata(label => 'oldest_update_age', value => $oldest || 0, uom => 's');
  };
  if ($@) {
    $self->add_unknown("my-updates: ".NetEyeSap::clean_error($@));
  }
}


#############################################################################
# --mode my-locks
#   reads the lock table (ENQUEUE_READ, like SM12) and counts locks older than --lookback seconds
#   --name   client passed to ENQUEUE_READ (default *)
#   --name2  user passed to ENQUEUE_READ (default *)
#   --name3  optional regexp on lock table name (GNAME) to be checked
#############################################################################
package MyLocks;
our @ISA = qw(Classes::SAP::Netweaver);
use strict;

sub init {
  my ($self) = @_;
  eval {
    my $maxage = $self->opts->lookback || 86400;
    my $now = time;
    my $fl = $self->session->function_lookup("ENQUEUE_READ");
    my $fc = $fl->create_function_call;
    $fc->GCLIENT($self->opts->name || '*');
    $fc->GUNAME($self->opts->name2 || '*');
    $fc->invoke;
    my $subrc = $fc->SUBRC;
    die sprintf("ENQUEUE_READ returned SUBRC %s\n", $subrc) if defined $subrc && $subrc =~ /^\d+$/ && $subrc != 0;
    my @all = map {
      my $raw = $_;
      my %row = map { $_ => NetEyeSap::strip($raw->{$_}) } keys %{$raw};
      \%row;
    } @{$fc->ENQ};
    if (@all && ! exists $all[0]->{GTDATE}) {
      die "ENQUEUE_READ: field GTDATE not returned, cannot compute lock age\n";
    }
    my $table_re = $self->opts->name3;
    my @locks = grep { ! $table_re || $_->{GNAME} =~ /$table_re/i } @all;
    foreach (@locks) {
      $_->{epoch} = NetEyeSap::epoch($_->{GTDATE}, $_->{GTTIME});
      $_->{age} = defined $_->{epoch} ? $now - $_->{epoch} : undef;
    }
    my @old = sort { $b->{age} <=> $a->{age} } grep { defined $_->{age} && $_->{age} > $maxage } @locks;
    my ($oldest) = sort { $b <=> $a } map { $_->{age} } grep { defined $_->{age} } @locks;
    my $summary = @old ?
        sprintf("%d of %d lock entries older than %s, oldest %s",
            scalar(@old), scalar(@locks), NetEyeSap::age_text($maxage), NetEyeSap::age_text($old[0]->{age})) :
        sprintf("%d lock entries, none older than %s", scalar(@locks), NetEyeSap::age_text($maxage));
    NetEyeSap::evaluate($self,
        metric => 'old_locks', value => scalar(@old), summary => $summary,
        details => [map {
          sprintf "client %s user %s table %s arg %s tcode %s age %s", $_->{GCLIENT}, $_->{GUNAME},
              $_->{GNAME}, $_->{GARG}, ($_->{GTCODE} || '-'), NetEyeSap::age_text($_->{age});
        } @old]);
    $self->add_perfdata(label => 'locks', value => scalar(@locks));
    $self->add_perfdata(label => 'oldest_lock_age', value => $oldest || 0, uom => 's');
  };
  if ($@) {
    $self->add_unknown("my-locks: ".NetEyeSap::clean_error($@));
  }
}


#############################################################################
# --mode my-queues
#   qRFC queues in error state (TRFCQOUT = SMQ1 outbound, TRFCQIN = SMQ2 inbound)
#   --name   in | out | both (default both)
#   --name2  comma separated list of error states
#            (default SYSFAIL,CPICERR,STOP,WAITSTOP,ANORETRY)
#   --name3  optional regexp on "<client>/<queue>" to restrict the check (e.g. ^500/)
#############################################################################
package MyQueues;
our @ISA = qw(Classes::SAP::Netweaver);
use strict;

sub init {
  my ($self) = @_;
  eval {
    my $direction = lc($self->opts->name || 'both');
    die "--name must be in, out or both\n" if $direction !~ /^(in|out|both)$/;
    my @states = map { uc NetEyeSap::strip($_) } split(/,/, $self->opts->name2 || 'SYSFAIL,CPICERR,STOP,WAITSTOP,ANORETRY');
    my $where = sprintf "QSTATE IN (%s)", join(",", map { "'$_'" } @states);
    my $queue_re = $self->opts->name3;
    my %result = ();
    foreach my $dir (qw(in out)) {
      next if $direction ne 'both' && $direction ne $dir;
      my ($table, $fields) = $dir eq 'in' ?
          ("TRFCQIN", [qw(MANDT QNAME QSTATE)]) :
          ("TRFCQOUT", [qw(MANDT QNAME DEST QSTATE)]);
      my $rows = NetEyeSap::read_table($self->session, $table, $fields, $where, 10000);
      my %queues = ();
      foreach my $r (@{$rows}) {
        my $id = $r->{MANDT}."/".$r->{QNAME};
        next if $queue_re && $id !~ /$queue_re/i;
        my $key = $id.($dir eq 'out' ? " -> ".$r->{DEST} : "");
        $queues{$key}->{entries}++;
        $queues{$key}->{states}->{$r->{QSTATE}}++;
      }
      $result{$dir} = \%queues;
    }
    my @details = ();
    my $total = 0;
    my @parts = ();
    foreach my $dir (sort keys %result) {
      my $q = $result{$dir};
      my $n = scalar(keys %{$q});
      $total += $n;
      push(@parts, sprintf "%d %sbound", $n, $dir);
      foreach my $name (sort keys %{$q}) {
        push(@details, sprintf "%sbound %s: %s (%d entries)", $dir, $name,
            join("/", sort keys %{$q->{$name}->{states}}), $q->{$name}->{entries});
      }
      my $entries = 0;
      map { $entries += $_->{entries} } values %{$q};
      $self->add_perfdata(label => "q${dir}_error_entries", value => $entries);
    }
    my $summary = $total ?
        sprintf("%d qRFC queue(s) in error state (%s)", $total, join(", ", @parts)) :
        sprintf("no qRFC queues in state %s", join("/", @states));
    NetEyeSap::evaluate($self,
        metric => 'error_queues', value => $total, summary => $summary, details => \@details);
  };
  if ($@) {
    $self->add_unknown("my-queues: ".NetEyeSap::clean_error($@));
  }
}

1;
