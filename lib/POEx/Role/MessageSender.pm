{package POEx::Role::MessageSender;}

#ABSTRACT: Utility Role for sending messages across wheels

use MooseX::Declare;

role POEx::Role::MessageSender
{
    use MooseX::Types::Moose(':all');
    use MooseX::AttributeHelpers;
    use POEx::Types(':all');
    use POEx::Role::MessageSender::Types(':all');
    use POEx::Role::MessageSender::Exception::NoWheelExists;

    use aliased 'POEx::Role::MessageSender::Exception::NoWheelExists';
    use aliased 'POEx::Role::Event';

    requires qw/has_wheel get_wheel next_message_id/;

=attr message_contexts: traits: ['Hash'], isa: HashRef[Ref], clearer: 'clear_message_contexts'

message_contexts stores context related data of messages where a result is expected.

It has no accessors beyond those provided by Native::Trait::Hash
        
    handles => 
    {
        get_message_context       => 'get'
        set_message_context       => 'set'
        delete_message_context    => 'delete'
        count_message_contexts    => 'count'
        has_message_context       => 'exists'
        all_message_contexts      => 'values'
    }

=cut

    has message_contexts =>
    (
        traits      => ['Hash'],
        isa         => HashRef[Ref],
        lazy        => 1,
        default     => sub { {} },
        clearer     => 'clear_message_contexts',
        handles     => 
        {
            get_message_context       => 'get'
            set_message_context       => 'set'
            delete_message_context    => 'delete'
            count_message_contexts    => 'count'
            has_message_context       => 'exists'
            all_message_contexts      => 'values'
        }

    );

=method send_message(DoesMessage :$message, WheelID :$wheel_id) is Event

This method sends a message via the Wheel that $wheel_id identifies. It checks
that such a Wheel does indeed exist and if not, throws a NoWheelExists
exception with the wheel_id attribute set to $wheel_id.

If the message does not have an ID associated with it already, one is attached
via next_message_id.

=cut

    method send_message(DoesMessage :$message, WheelID :$wheel_id) is Event
    {   
        NoWheelExists->throw({wheel_id => $wheel_id}) if !$self->has_wheel($wheel_id);
        $message->id($self->next_message_id()) if !$message->has_id();
        $self->get_wheel($wheel_id)->put($message);
    }


=method send_context_message(DoesMessage :$message, WheelID :$wheel_id, Ref :$tag?) is Event

This method sends a message, and also stores context information related to the
message. Useful for protocols where responses are related to requests by a
message id.

If the message does not have an ID associated with it already, one is attached
via next_message_id.

=cut

    method send_context_message(DoesMessage :$message, WheelID :$wheel_id, Ref :$tag?) is Event
    {
        NoWheelExists->throw({wheel_id => $wheel_id}) if !$self->has_wheel($wheel_id);
        
        if(is_Session($return_session) or is_DoesSessionInstantiation($return_session))
        {
            $return_session = $return_session->ID;
        }

        $message->id($self->next_message_id()) if !$message->has_id();
        $self->set_message_context(message => $message, tag => $tag);
        $self->get_wheel($wheel_id)->put($message);
    }

    method store_message_context(DoesMessage :$message, Ref :$tag?)
    {
        $self->set_message_context($message->id, $tag);
    }
}
1;
__END__
=head1 DESCRIPTION

POEx::Role::MessageSender is a utility role provides common behavior for
sending messages via POE::Wheels. 

=head1 REQUIREMENTS

In order to consume this role, your entity must implement a couple of methods.

=over 4

=item has_wheel(WheelID $wheel_id)

has_wheel must take a WheelID as an argument and return a boolean result.

=item get_wheel(WheelID $wheel_id)

get_wheel must take a WheelID and return the associated Wheel as a result.

=item next_message_id() returns (Any)

next_message_id can return any value that is appropriate for the protocol, but,
it should be unique when using send_context_message or else, there will be
context collisions.

=back

