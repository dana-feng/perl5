#!/usr/bin/env perl
use strict;
use warnings;
use 5.010;
use JSON;
use Data::Dumper;
use File::Slurp;
use DateTime;
use List::Util qw(first);

package TaskManager::Task;
use DateTime;

sub new {
    my ($class, %args) = @_;
    
    my $self = {
        id => $args{id} || die "Task ID required",
        title => $args{title} || die "Task title required",
        description => $args{description} || '',
        status => $args{status} || 'pending',
        priority => $args{priority} || 'medium',
        created_at => $args{created_at} || DateTime->now->iso8601,
        updated_at => $args{updated_at} || DateTime->now->iso8601,
        assigned_to => $args{assigned_to} || undef,
        tags => $args{tags} || [],
        due_date => $args{due_date} || undef,
    };
    
    return bless $self, $class;
}

sub to_hash {
    my ($self) = @_;
    return { %$self };
}

sub update_status {
    my ($self, $new_status) = @_;
    
    my @valid_statuses = qw(pending in_progress completed cancelled);
    die "Invalid status: $new_status" unless grep { $_ eq $new_status } @valid_statuses;
    
    $self->{status} = $new_status;
    $self->{updated_at} = DateTime->now->iso8601;
    
    return $self;
}

sub add_tag {
    my ($self, $tag) = @_;
    push @{$self->{tags}}, $tag unless grep { $_ eq $tag } @{$self->{tags}};
    $self->{updated_at} = DateTime->now->iso8601;
    return $self;
}

sub remove_tag {
    my ($self, $tag) = @_;
    $self->{tags} = [grep { $_ ne $tag } @{$self->{tags}}];
    $self->{updated_at} = DateTime->now->iso8601;
    return $self;
}

sub is_overdue {
    my ($self) = @_;
    return 0 unless $self->{due_date};
    
    my $due = DateTime->from_epoch(epoch => $self->{due_date});
    return DateTime->now > $due;
}

package TaskManager::Storage;
use JSON;
use File::Slurp;

sub new {
    my ($class, $filename) = @_;
    
    my $self = {
        filename => $filename || 'tasks.json',
        tasks => {},
    };
    
    bless $self, $class;
    $self->load_tasks();
    
    return $self;
}

sub load_tasks {
    my ($self) = @_;
    
    return unless -f $self->{filename};
    
    my $json_text = read_file($self->{filename});
    my $data = decode_json($json_text);
    
    for my $task_data (@{$data->{tasks} || []}) {
        # Ensure all required fields have default values
        $task_data->{id} //= '';
        $task_data->{title} //= '';
        $task_data->{description} //= '';
        $task_data->{status} //= 'pending';
        $task_data->{priority} //= 'medium';
        $task_data->{created_at} //= DateTime->now->iso8601;
        $task_data->{updated_at} //= DateTime->now->iso8601;
        $task_data->{assigned_to} //= undef;
        $task_data->{tags} //= [];
        $task_data->{due_date} //= undef;
        
        my $task = TaskManager::Task->new(%$task_data);
        $self->{tasks}->{$task->{id}} = $task;
    }
}

sub save_tasks {
    my ($self) = @_;
    
    my @task_list = map { $_->to_hash } values %{$self->{tasks}};
    my $data = { tasks => \@task_list };
    
    write_file($self->{filename}, encode_json($data));
}

sub add_task {
    my ($self, $task) = @_;
    
    die "Task with ID $task->{id} already exists" if exists $self->{tasks}->{$task->{id}};
    
    $self->{tasks}->{$task->{id}} = $task;
    $self->save_tasks();
    
    return $task;
}

sub get_task {
    my ($self, $id) = @_;
    return $self->{tasks}->{$id};
}

sub get_all_tasks {
    my ($self) = @_;
    return values %{$self->{tasks}};
}

sub delete_task {
    my ($self, $id) = @_;
    my $task = delete $self->{tasks}->{$id};
    $self->save_tasks() if $task;
    return $task;
}

sub update_task {
    my ($self, $id, %updates) = @_;
    
    my $task = $self->{tasks}->{$id} or die "Task $id not found";
    
    for my $field (keys %updates) {
        $task->{$field} = $updates{$field};
    }
    
    $task->{updated_at} = DateTime->now->iso8601;
    $self->save_tasks();
    
    return $task;
}

package TaskManager::CLI;

sub new {
    my ($class, $storage) = @_;
    
    my $self = {
        storage => $storage,
        commands => {
            add => 'cmd_add',
            list => 'cmd_list',
            show => 'cmd_show',
            update => 'cmd_update',
            delete => 'cmd_delete',
            complete => 'cmd_complete',
            help => 'cmd_help',
        }
    };
    
    return bless $self, $class;
}

sub run {
    my ($self, @args) = @_;
    
    my $command = shift @args || 'help';
    
    if (exists $self->{commands}->{$command}) {
        my $method = $self->{commands}->{$command};
        $self->$method(@args);
    } else {
        say "Unknown command: $command";
        $self->cmd_help();
    }
}

sub cmd_list {
    my ($self, @args) = @_;
    
    my @tasks = $self->{storage}->get_all_tasks();
    
    if (@args && $args[0] eq '--status') {
        my $status = $args[1] or die "Usage: list --status <status>";
        @tasks = grep { $_->{status} eq $status } @tasks;
    }
    
    if (@tasks) {
        say sprintf("%-15s %-10s %-30s %-15s", "ID", "Status", "Title", "Updated");
        say "-" x 70;
        
        for my $task (sort { 
            my $a_date = $a->{created_at} // '';
            my $b_date = $b->{created_at} // '';
            $a_date cmp $b_date 
        } @tasks) {
            my $updated = '';
            if ($task->{updated_at}) {
                $updated = substr($task->{updated_at}, 0, 10);
            }
            
            my $title = $task->{title} // '';
            my $status = $task->{status} // '';
            my $id = $task->{id} // '';
            
            say sprintf("%-15s %-10s %-30s %-15s", 
                $id, $status, 
                substr($title, 0, 30), $updated);
        }
    } else {
        say "No tasks found.";
    }
}

sub cmd_add {
    my ($self, @args) = @_;
    
    my ($title, $description) = @args;
    die "Usage: add <title> [description]" unless $title;
    
    my $id = sprintf("task_%d", time() + int(rand(1000)));
    
    my $task = TaskManager::Task->new(
        id => $id,
        title => $title,
        description => $description || '',
    );
    
    $self->{storage}->add_task($task);
    say "Added task: $id - $title";
}

sub cmd_show {
    my ($self, $id) = @_;
    die "Usage: show <task_id>" unless $id;
    
    my $task = $self->{storage}->get_task($id) or die "Task $id not found";
    
    say "Task Details:";
    say "  ID: $task->{id}";
    say "  Title: $task->{title}";
    say "  Description: $task->{description}";
    say "  Status: $task->{status}";
    say "  Priority: $task->{priority}";
    say "  Created: $task->{created_at}";
    say "  Updated: $task->{updated_at}";
    say "  Assigned to: " . ($task->{assigned_to} || 'Unassigned');
    say "  Tags: " . join(', ', @{$task->{tags}});
    say "  Due date: " . ($task->{due_date} || 'None');
}

sub cmd_update {
    my ($self, $id, $field, $value) = @_;
    die "Usage: update <task_id> <field> <value>" unless $id && $field && defined $value;
    
    my $task = $self->{storage}->update_task($id, $field => $value);
    say "Updated task $id: $field = $value";
}

sub cmd_complete {
    my ($self, $id) = @_;
    die "Usage: complete <task_id>" unless $id;
    
    my $task = $self->{storage}->get_task($id) or die "Task $id not found";
    $task->update_status('completed');
    $self->{storage}->save_tasks();
    
    say "Marked task $id as completed";
}

sub cmd_delete {
    my ($self, $id) = @_;
    die "Usage: delete <task_id>" unless $id;
    
    my $task = $self->{storage}->delete_task($id) or die "Task $id not found";
    say "Deleted task: $task->{title}";
}

sub cmd_help {
    my ($self) = @_;
    
    say "Task Manager Commands:";
    say "  add <title> [description]     - Add a new task";
    say "  list [--status <status>]      - List all tasks or by status";
    say "  show <task_id>                - Show task details";
    say "  update <task_id> <field> <val> - Update a task field";
    say "  complete <task_id>            - Mark task as completed";
    say "  delete <task_id>              - Delete a task";
    say "  help                          - Show this help";
}

# Main execution
package main;

sub main {
    my $storage = TaskManager::Storage->new('tasks.json');
    my $cli = TaskManager::CLI->new($storage);
    
    if (@ARGV) {
        $cli->run(@ARGV);
    } else {
        # Interactive mode
        say "Task Manager - Type 'help' for commands, 'quit' to exit";
        
        while (1) {
            print "> ";
            my $input = <STDIN>;
            chomp $input;
            
            last if $input eq 'quit' || $input eq 'exit';
            next if $input eq '';
            
            my @args = split /\s+/, $input;
            
            eval {
                $cli->run(@args);
            };
            
            if ($@) {
                say "Error: $@";
            }
        }
    }
}

main() unless caller;