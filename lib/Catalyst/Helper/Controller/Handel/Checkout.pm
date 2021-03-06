# $Id$
## no critic (ProhibitCaptureWithoutTest)
package Catalyst::Helper::Controller::Handel::Checkout;
use strict;
use warnings;

BEGIN {
    use Catalyst 5.7001;
    use Catalyst::Utils;
    use Path::Class;
};

=head1 NAME

Catalyst::Helper::Controller::Handel::Checkout - Helper for Handel::Checkout Controllers

=head1 SYNOPSIS

    script/create.pl controller <newclass> Handel::Checkout [<cartmodel> <ordermodel> <cartcontroller> <ordercontroller>]
    script/create.pl controller Checkout Handel::Checkout

=head1 DESCRIPTION

A Helper for creating controllers based on Handel::Checkout objects. IF no cartmodel or
ordermodel was specified, ::M::Cart and ::M::Orders is assumed.

The cartmode, ordermodel, cartcontroller and ordercontroller arguments try to do the
right thing with the names given to them.

For example, you can pass the shortened class name without the MyApp::M/C, or pass the fully
qualified package name:

    MyApp::M::CartModel
    MyApp::Model::CartModel
    CartModel

In all three cases everything before M{odel)|C(ontroller) will be stripped and the class CartModel
will be used.

B<The code generated by this helper requires FormValidator::Simple, HTML::FIllInForm and YAML to be
installed to operate.>

=head1 METHODS

=head2 mk_compclass

Makes a Handel::Checkout Controller class and template files for you.

=cut

sub mk_compclass {
    my ($self, $helper, $cmodel, $omodel, $ccontroller, $ocontroller) = @_;
    my $file = $helper->{'file'};
    my $dir  = dir($helper->{'base'}, 'root', $helper->{'uri'});

    $cmodel      ||= 'Cart';
    $omodel      ||= 'Order';
    $ccontroller ||= 'Cart';
    $ocontroller ||= 'Order';

    $ccontroller =~ /^(.*::C(ontroller)?::)?(.*)$/i;
    $ccontroller = $3 ? $3 : 'Cart';
    $helper->{'ccontroller'} = $ccontroller;

    $ocontroller =~ /^(.*::C(ontroller)?::)?(.*)$/i;
    $ocontroller = $3 ? $3 : 'Order';
    $helper->{'ocontroller'} = $ocontroller;

    $cmodel =~ /^(.*::M(odel)?::)?(.*)$/i;
    $cmodel = $3 ? $3 : 'Cart';
    $helper->{'cmodel'} = $cmodel;

    $omodel =~ /^(.*::M(odel)?::)?(.*)$/i;
    $omodel = $3 ? $3 : 'Order';
    $helper->{'omodel'} = $omodel;

    #$ccontroller =~ /^(.*::C(ontroller)?::)?(.*)$/i;
    my $curi = $ccontroller;
    $curi =~ s/::/\//g;
    $helper->{'curi'} = $curi;

    #$ocontroller =~ /^(.*::C(ontroller)?::)?(.*)$/i;
    my $ouri = $ocontroller;
    $ouri =~ s/::/\//g;
    $helper->{'ouri'} = $ouri;

    $helper->{'action'} = Catalyst::Utils::class2prefix($helper->{'class'});

    $helper->mk_dir($dir);
    $helper->render_file('controller', $file);

    $helper->render_file('default', file($dir, 'default'));
    $helper->render_file('billing', file($dir, 'billing'));
    $helper->render_file('billing', file($dir, 'billing'));
    $helper->render_file('preview', file($dir, 'preview'));
    $helper->render_file('payment', file($dir, 'payment'));
    $helper->render_file('complete', file($dir, 'complete'));

    $helper->render_file('errors', file($dir, 'errors'));
    $helper->render_file('profiles', file($dir, 'profiles.yml'));
    $helper->render_file('messages', file($dir, 'messages.yml'));

    return 1;
};

=head2 mk_comptest

Makes a Handel::Checkout Controller test for you.

=cut

sub mk_comptest {
    my ($self, $helper) = @_;
    my $test = $helper->{'test'};

    $helper->render_file('test', $test);

    return 1;
};

=head1 SEE ALSO

L<Catalyst::Manual>, L<Catalyst::Helper>, L<Handel::Checkout>

=head1 AUTHOR

    Christopher H. Laco
    CPAN ID: CLACO
    claco@chrislaco.com
    http://today.icantfocus.com/blog/

=cut

1;
__DATA__

=begin pod_to_ignore

__controller__
package [% class %];
use strict;
use warnings;

BEGIN {
    use base qw/Catalyst::Controller/;
    use Handel::Checkout;
    use Handel::Constants qw/:cart :order :checkout/;
    use FormValidator::Simple 0.17;
    use HTML::FillInForm;
    use YAML 0.65;
};

=head1 NAME

[% class %] - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=head2 COMPONENT

=cut

sub COMPONENT {
    my $self = shift->NEXT::COMPONENT(@_);

    $self->{'validator'} = FormValidator::Simple->new;
    $self->{'validator'}->set_messages(
        $_[0]->path_to('root', '[% action %]', 'messages.yml')
    );

    $self->{'fif'} = HTML::FillInForm->new;

    $self->{'profiles'} = YAML::LoadFile($_[0]->path_to('root', '[% action %]', 'profiles.yml'));

    return $self;
};

=head2 default 

Default action when browsing to [% uri %]/ that loads the checkout process for
the current shopper. If no session exists, or the shopper id isn't set, or there
os no temporary order record, nothing will be loaded. This keeps non-shoppers 
like Google and others from wasting sessions and order records for no good
reason.

=cut

sub default : Private {
    my ($self, $c) = @_;
    $c->stash->{'template'} = '[% action %]/default';

    if ($c->forward('load')) {
        $c->res->redirect($c->uri_for('[% uri %]/billing/'));
    };

    return;
};

=head2 billing

Loads/saves the billing and shipping information during GET/POST.

    [% uri %]/billing/

=cut

sub billing : Local {
    my ($self, $c) = @_;
    $c->stash->{'template'} = '[% action %]/billing';

    if (my $order = $c->forward('load')) {
        $c->stash->{'order'} = $order;

        if ($c->req->method eq 'POST') {
            if ($c->forward('validate')) {
                my $checkout = Handel::Checkout->new({
                    order  => $order,
                    phases => 'CHECKOUT_PHASE_VALIDATE'
                });

                if ($checkout->process == CHECKOUT_STATUS_OK) {
                    if ($checkout->order->update($c->req->params)) {
                        $c->res->redirect($c->uri_for('[% uri %]/preview/'));
                    };
                } else {
                    $c->stash->{'errors'} = $checkout->messages;
                };
            };
        };
    } else {
        $c->res->redirect($c->uri_for('[% uri %]/'));
    };

    return;
};

=head2 load

Loads the current temporary order for the current shopper.

    my $order = $c->forward('load');

=cut

sub load : Private {
    my ($self, $c) = @_;

    if ($c->sessionid && $c->session->{'shopper'}) {
        if (my $order = $c->forward($c->controller('[% ocontroller %]'), 'load')) {
            $order->reconcile(
                $c->forward($c->controller('[% ccontroller %]'), 'load')
            );

            return $order;
        } elsif (my $cart = $c->forward($c->controller('[% ccontroller %]'), 'load')) {
            if ($cart->count) {
                if (my $order = $c->forward($c->controller('[% ocontroller %]'), 'create', [$cart])) {
                    
                    my $checkout = Handel::Checkout->new({
                        order   => $order,
                        phases => 'CHECKOUT_PHASE_INITIALIZE'
                    });

                    if ($checkout->process != CHECKOUT_STATUS_OK) {
                        $c->stash->{'errors'} = $checkout->messages;
                    };                    
                    
                    return $checkout->order;
                };
            };
        };
    };

    return;
};

=head2 payment

Loads/Saves the payment information during GET/POST.

    [% uri %]/payment/

=cut

sub payment : Local {
    my ($self, $c) = @_;
    $c->stash->{'template'} = '[% action %]/payment';

    if (my $order = $c->forward('load')) {
        $c->stash->{'order'} = $order;

        if ($c->req->method eq 'POST') {
            if ($c->forward('validate')) {
                my $checkout = Handel::Checkout->new({
                    order  => $order,
                    phases => 'CHECKOUT_PHASE_AUTHORIZE, CHECKOUT_PHASE_FINALIZE, CHECKOUT_PHASE_DELIVER'
                });

                if ($checkout->process == CHECKOUT_STATUS_OK) {
                    if ($checkout->order->update) {
                        eval {
                            $c->model('[% cmodel %]')->destroy({
                                shopper => $c->session->{'shopper'},
                                type    => CART_TYPE_TEMP
                            });
                        };
                        $c->stash->{'order'} = $checkout->order;
                        $c->forward('complete');
                    };
                } else {
                    $c->stash->{'errors'} = $checkout->messages;
                };
            };
        };
    } else {
        $c->res->redirect($c->uri_for('[% uri %]/'));
    };

    return;
};

=head2 preview

Displays a preview of the current order.

    [% uri %]/preview/

=cut

sub preview : Local {
    my ($self, $c) = @_;
    $c->stash->{'template'} = '[% action %]/preview';

    if (my $order = $c->forward('load')) {
        $c->stash->{'order'} = $order;
    } else {
        $c->res->redirect($c->uri_for('[% uri %]/'));
    };

    return;
};

=head2 complete

Displays the order complete page.

=cut

sub complete : Local {
    my ($self, $c) = @_;
    $c->stash->{'template'} = '[% action %]/complete';

    if (!$c->stash->{'order'}) {
        $c->res->redirect($c->uri_for('[% uri %]/'));
    };
};

=head2 render

Local render method to attach the load end method and HTML::FIllInForm to.

=cut

sub render : ActionClass('RenderView') {};

=head2 end

Runs HTML::FillInForm on the curret request before sending the output to the
browser.

=cut

sub end : Private { 
    my ($self, $c) = @_;
    $c->forward('render');

    if ($c->req->method eq 'POST') {
        $c->res->output(
            $self->{'fif'}->fill(
                scalarref => \$c->response->{body},
                fdat => $c->req->params
            )
        );
    };
};

=head2 validate

Validates the current form parameters using the profile in profiles.yml that
matches the current action.

    if ($c->forward('validate')) {
    
    };

=cut

sub validate : Private {
    my ($self, $c) = @_;

    $self->{'validator'}->results->clear;

    my $results = $self->{'validator'}->check(
        $c->req,
        $self->{'profiles'}->{$c->action}
    );

    if ($results->success) {
        return $results;
    } else {
        $c->stash->{'errors'} = $results->messages($c->action);
    };

    return;
};

=head1 AUTHOR

A clever guy

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
__test__
use Test::More tests => 3;
use strict;
use warnings;

use_ok('Catalyst::Test', '[% app %]');
use_ok('[% class %]');

ok(request('[% uri %]')->is_success, 'Request should succeed');
__default__
<h1>Checkout</h1>
<p>Your shopping cart is empty.</p>
__billing__
[% TAGS [- -] -%]
[% USE HTML %]
<h1>Billing/Shipping Information</h1>
[% INCLUDE [- action -]/errors %]
<form action="[% c.uri_for('[- uri -]/billing/') %]" method="POST">
    <table border="0" cellpadding="3" cellspacing="5">
        <tr>
            <th colspan="2" align="left">Billing</th>
            <th width="25"></th>
            <th colspan="2" align="left">Shipping</th>
        </tr>
        <tr>
            <td colspan="5" height="5">&nbsp;</td>
        </tr>
        <tr>
            <td align="right">First Name:</td>
            <td align="left"><input type="text" name="billtofirstname" value="[% HTML.escape(order.billtofirstname) %]" tabindex="1"></td>
            <td></td>
            <td align="right">First Name:</td>
            <td align="left"><input type="text" name="shiptofirstname" value="[% HTML.escape(order.shiptofirstname) %]" tabindex="14"></td>
        </tr>
        <tr>
            <td align="right">Last Name:</td>
            <td align="left"><input type="text" name="billtolastname" value="[% HTML.escape(order.billtolastname) %]" tabindex="2"></td>
            <td></td>
            <td align="right">Last Name:</td>
            <td align="left"><input type="text" name="shiptolastname" value="[% HTML.escape(order.shiptolastname) %]" tabindex="15"></td>
        </tr>
        <tr>
            <td colspan="5" height="5">&nbsp;</td>
        </tr>
        <tr>
            <td align="right">Address:</td>
            <td align="left"><input type="text" name="billtoaddress1" value="[% HTML.escape(order.billtoaddress1) %]" tabindex="3"></td>
            <td></td>
            <td align="right">Address:</td>
            <td align="left"><input type="text" name="shiptoaddress1" value="[% HTML.escape(order.shiptoaddress1) %]" tabindex="16"></td>
        </tr>
        <tr>
            <td align="right"></td>
            <td align="left"><input type="text" name="billtoaddress2" value="[% HTML.escape(order.billtoaddress2) %]" tabindex="4"></td>
            <td></td>
            <td align="right"></td>
            <td align="left"><input type="text" name="shiptoaddress2" value="[% HTML.escape(order.shiptoaddress2) %]" tabindex="17"></td>
        </tr>
        <tr>
            <td align="right"></td>
            <td align="left"><input type="text" name="billtoaddress3" value="[% HTML.escape(order.billtoaddress3) %]" tabindex="5"></td>
            <td></td>
            <td align="right"></td>
            <td align="left"><input type="text" name="shiptoaddress3" value="[% HTML.escape(order.shiptoaddress3) %]" tabindex="18"></td>
        </tr>
        <tr>
            <td align="right">City:</td>
            <td align="left"><input type="text" name="billtocity" value="[% HTML.escape(order.billtocity) %]" tabindex="6"></td>
            <td></td>
            <td align="right">City:</td>
            <td align="left"><input type="text" name="shiptocity" value="[% HTML.escape(order.shiptocity) %]" tabindex="19"></td>
        </tr>
        <tr>
            <td align="right">State/Province:</td>
            <td align="left"><input type="text" name="billtostate" value="[% HTML.escape(order.billtostate) %]" tabindex="7"></td>
            <td></td>
            <td align="right">State/Province:</td>
            <td align="left"><input type="text" name="shiptostate" value="[% HTML.escape(order.shiptostate) %]" tabindex="20"></td>
        </tr>
        <tr>
            <td align="right">Zip/Postal Code:</td>
            <td align="left"><input type="text" name="billtozip" value="[% HTML.escape(order.billtozip) %]" tabindex="8"></td>
            <td></td>
            <td align="right">Zip/Postal Code:</td>
            <td align="left"><input type="text" name="shiptozip" value="[% HTML.escape(order.shiptozip) %]" tabindex="21"></td>
        </tr>
        <tr>
            <td align="right">Country:</td>
            <td align="left"><input type="text" name="billtocountry" value="[% HTML.escape(order.billtocountry) %]" tabindex="9"></td>
            <td></td>
            <td align="right">Country:</td>
            <td align="left"><input type="text" name="shiptocountry" value="[% HTML.escape(order.shiptocountry) %]" tabindex="22"></td>
        </tr>
        <tr>
            <td align="right">Day Phone:</td>
            <td align="left"><input type="text" name="billtodayphone" value="[% HTML.escape(order.billtodayphone) %]" tabindex="10"></td>
            <td></td>
            <td align="right">Day Phone:</td>
            <td align="left"><input type="text" name="shiptodayphone" value="[% HTML.escape(order.shiptodayphone) %]" tabindex="23"></td>
        </tr>
        <tr>
            <td align="right">Night Phone:</td>
            <td align="left"><input type="text" name="billtonightphone" value="[% HTML.escape(order.billtonightphone) %]" tabindex="11"></td>
            <td></td>
            <td align="right">Night Phone:</td>
            <td align="left"><input type="text" name="shiptonightphone" value="[% HTML.escape(order.shiptonightphone) %]" tabindex="24"></td>
        </tr>
        <tr>
            <td align="right">Fax:</td>
            <td align="left"><input type="text" name="billtofax" value="[% HTML.escape(order.billtofax) %]" tabindex="12"></td>
            <td></td>
            <td align="right">Fax:</td>
            <td align="left"><input type="text" name="shiptofax" value="[% HTML.escape(order.shiptofax) %]" tabindex="25"></td>
        </tr>
        <tr>
            <td align="right">Email:</td>
            <td align="left"><input type="text" name="billtoemail" value="[% HTML.escape(order.billtoemail) %]" tabindex="13"></td>
            <td></td>
            <td align="right">Email:</td>
            <td align="left"><input type="text" name="shiptoemail" value="[% HTML.escape(order.shiptoemail) %]" tabindex="26"></td>
        </tr>
        <tr>
            <td colspan="5" height="10">&nbsp;</td>
        </tr>
        <tr>
            <td align="right" valign="top">Comments:</td>
            <td colspan="4" valign="top">
                <textarea name="comments" cols="45" rows="10" tabindex="27">[% HTML.escape(order.comments) %]</textarea>
            </td>
        </tr>
        <tr>
            <td colspan="5" height="10">&nbsp;</td>
        </tr>
        <tr>
            <td colspan="5" align="right"><input type="submit" value="Continue" tabindex="28"></td>
        </tr>
    </table>
</form>
__preview__
[% TAGS [- -] -%]
[% USE HTML %]
<h1>Order Preview</h1>
<table border="0" cellpadding="3" cellspacing="5">
    <tr>
        <th colspan="2" align="left">Billing</th>
        <th width="50"></th>
        <th colspan="2" align="left">Shipping</th>
    </tr>
    <tr>
        <td colspan="5" height="5">&nbsp;</td>
    </tr>
    <tr>
        <td align="right">First Name:</td>
        <td align="left">[% HTML.escape(order.billtofirstname) %]</td>
        <td></td>
        <td align="right">First Name:</td>
        <td align="left">[% HTML.escape(order.shiptofirstname) %]</td>
    </tr>
    <tr>
        <td align="right">Last Name:</td>
        <td align="left">[% HTML.escape(order.billtolastname) %]</td>
        <td></td>
        <td align="right">Last Name:</td>
        <td align="left">[% HTML.escape(order.shiptolastname) %]</td>
    </tr>
    <tr>
        <td colspan="5" height="5">&nbsp;</td>
    </tr>
    <tr>
        <td align="right">Address:</td>
        <td align="left">[% HTML.escape(order.billtoaddress1) %]</td>
        <td></td>
        <td align="right">Address:</td>
        <td align="left">[% HTML.escape(order.shiptoaddress1) %]</td>
    </tr>
    <tr>
        <td align="right"></td>
        <td align="left">[% HTML.escape(order.billtoaddress2) %]</td>
        <td></td>
        <td align="right"></td>
        <td align="left">[% HTML.escape(order.shiptoaddress2) %]</td>
    </tr>
    <tr>
        <td align="right"></td>
        <td align="left">[% HTML.escape(order.billtoaddress3) %]</td>
        <td></td>
        <td align="right"></td>
        <td align="left">[% HTML.escape(order.shiptoaddress3) %]</td>
    </tr>
    <tr>
        <td align="right">City:</td>
        <td align="left">[% HTML.escape(order.billtocity) %]</td>
        <td></td>
        <td align="right">City:</td>
        <td align="left">[% HTML.escape(order.shiptocity) %]</td>
    </tr>
    <tr>
        <td align="right">State/Province:</td>
        <td align="left">[% HTML.escape(order.billtostate) %]</td>
        <td></td>
        <td align="right">State/Province:</td>
        <td align="left">[% HTML.escape(order.shiptostate) %]</td>
    </tr>
    <tr>
        <td align="right">Zip/Postal Code:</td>
        <td align="left">[% HTML.escape(order.billtozip) %]</td>
        <td></td>
        <td align="right">Zip/Postal Code:</td>
        <td align="left">[% HTML.escape(order.shiptozip) %]</td>
    </tr>
    <tr>
        <td align="right">Country:</td>
        <td align="left">[% HTML.escape(order.billtocountry) %]</td>
        <td></td>
        <td align="right">Country:</td>
        <td align="left">[% HTML.escape(order.shiptocountry) %]</td>
    </tr>
    <tr>
        <td align="right">Day Phone:</td>
        <td align="left">[% HTML.escape(order.billtodayphone) %]</td>
        <td></td>
        <td align="right">Day Phone:</td>
        <td align="left">[% HTML.escape(order.shiptodayphone) %]</td>
    </tr>
    <tr>
        <td align="right">Night Phone:</td>
        <td align="left">[% HTML.escape(order.billtonightphone) %]</td>
        <td></td>
        <td align="right">Night Phone:</td>
        <td align="left">[% HTML.escape(order.shiptonightphone) %]</td>
    </tr>
    <tr>
        <td align="right">Fax:</td>
        <td align="left">[% HTML.escape(order.billtofax) %]</td>
        <td></td>
        <td align="right">Fax:</td>
        <td align="left">[% HTML.escape(order.shiptofax) %]</td>
    </tr>
    <tr>
        <td align="right">Email:</td>
        <td align="left">[% HTML.escape(order.billtoemail) %]</td>
        <td></td>
        <td align="right">Email:</td>
        <td align="left">[% HTML.escape(order.shiptoemail) %]</td>
    </tr>
    <tr>
        <td colspan="5" height="5">&nbsp;</td>
    </tr>
    <tr>
        <td align="right" valign="top">Comments:</td>
        <td colspan="4" valign="top">[% HTML.escape(order.comments) %]</td>
    </tr>
    <tr>
        <td colspan="5" height="5">&nbsp;</td>
    </tr>
    <tr>
        <td colspan="5">
            <table border="0" cellpadding="3" cellspacing="5" width="100%">
                <tr>
                    <th align="left">SKU</th>
                    <th align="left">Description</th>
                    <th align="right">Price</th>
                    <th align="center">Quantity</th>
                    <th align="right">Total</th>
                </tr>
            [% FOREACH item = order.items %]
                <tr>
                        <td align="left">[% HTML.escape(item.sku) %]</td>
                        <td align="left">[% HTML.escape(item.description) %]</td>
                        <td align="right">[% HTML.escape(item.price.as_string('FMT_SYMBOL')) %]</td>
                        <td align="center">[% HTML.escape(item.quantity) %]</td>
                        <td align="right">[% HTML.escape(item.total.as_string('FMT_SYMBOL')) %]</td>
                </tr>
            [% END %]
                <tr>
                        <td align="right" colspan="4">Subtotal:</td>
                        <td align="right">[% HTML.escape(order.subtotal.as_string('FMT_SYMBOL')) %]</td>
                </tr>
                <tr>
                        <td align="right" colspan="4">Tax:</td>
                        <td align="right">[% HTML.escape(order.tax.as_string('FMT_SYMBOL')) %]</td>
                </tr>
                <tr>
                        <td align="right" colspan="4">Shipping:</td>
                        <td align="right">[% HTML.escape(order.shipping.as_string('FMT_SYMBOL')) %]</td>
                </tr>
                <tr>
                        <td align="right" colspan="4">Handling:</td>
                        <td align="right">[% HTML.escape(order.handling.as_string('FMT_SYMBOL')) %]</td>
                </tr>
                <tr>
                        <td align="right" colspan="4">Total:</td>
                        <td align="right">[% HTML.escape(order.total.as_string('FMT_SYMBOL')) %]</td>
                </tr>
                <tr>
                    <td colspan="5" height="5">&nbsp;</td>
                </tr>
                <tr>
                    <td colspan="5" align="right">
                        <form action="[% c.uri_for('[- uri -]/payment/') %]" method="GET">
                            <input type="submit" value="Continue">
                        </form>
                    </td>
                </tr>
            </table>
        </td>
    </td>
</table>
__payment__
[% TAGS [- -] -%]
[% USE HTML %]
<h1>Payment Information</h1>
[% INCLUDE [- action -]/errors %]
<form action="[% c.uri_for('[- uri -]/payment/') %]" method="POST">
    <table border="0" cellpadding="3" cellspacing="5">
        <tr>
            <td align="right">Name On Card:</td>
            <td align="left"><input type="text" name="ccname" value=""></td>
        </tr>
        <tr>
            <td align="right">Credit Card Type:</td>
            <td align="left">
                <select name="cctype">
                    <option>Visa</option>
                    <option>Mastercard</option>
                    <option>American Express</option>
                    <option>Discover</option>
                </select>
            </td>
        </tr>
        <tr>
            <td align="right">Credit Card Number:</td>
            <td align="left"><input type="text" name="ccn" value=""></td>
        </tr>
        <tr>
            <td align="right">Credit Card Expiration:</td>
            <td align="left"><input type="text" size="3" name="ccm" maxlength="2" value=""> / <input type="text" size="3" name="ccy" maxlength="2" value=""></td>
        </tr>
        <tr>
            <td align="right">Credit Card Verificaton Number:</td>
            <td align="left"><input type="text" name="ccvn" value="" maxlength="4" size="5"></td>
        </tr>
        <tr>
            <td colspan="2" align="right"><input type="submit" value="Complete Order"></td>
        </tr>
    </table>
</form>
__complete__
[% TAGS [- -] -%]
[% USE HTML %]
<h1>Order Complete!</h1>
<table border="0" cellpadding="3" cellspacing="5">
    <tr>
        <th colspan="2" align="left">Billing</th>
        <th width="50"></th>
        <th colspan="2" align="left">Shipping</th>
    </tr>
    <tr>
        <td colspan="5" height="5">&nbsp;</td>
    </tr>
    <tr>
        <td align="right">Order Number:</td>
        <td align="left">[% HTML.escape(order.number) %]</td>
        <td colspan="3"></td>
    </tr>
    <tr>
        <td align="right">Order Created:</td>
        <td align="left">[% HTML.escape(order.updated) %]</td>
        <td colspan="3"></td>
    </tr>
    <tr>
        <td colspan="5" height="5">&nbsp;</td>
    </tr>
    <tr>
        <td align="right">First Name:</td>
        <td align="left">[% HTML.escape(order.billtofirstname) %]</td>
        <td></td>
        <td align="right">First Name:</td>
        <td align="left">[% HTML.escape(order.shiptofirstname) %]</td>
    </tr>
    <tr>
        <td align="right">Last Name:</td>
        <td align="left">[% HTML.escape(order.billtolastname) %]</td>
        <td></td>
        <td align="right">Last Name:</td>
        <td align="left">[% HTML.escape(order.shiptolastname) %]</td>
    </tr>
    <tr>
        <td colspan="5" height="5">&nbsp;</td>
    </tr>
    <tr>
        <td align="right">Address:</td>
        <td align="left">[% HTML.escape(order.billtoaddress1) %]</td>
        <td></td>
        <td align="right">Address:</td>
        <td align="left">[% HTML.escape(order.shiptoaddress1) %]</td>
    </tr>
    <tr>
        <td align="right"></td>
        <td align="left">[% HTML.escape(order.billtoaddress2) %]</td>
        <td></td>
        <td align="right"></td>
        <td align="left">[% HTML.escape(order.shiptoaddress2) %]</td>
    </tr>
    <tr>
        <td align="right"></td>
        <td align="left">[% HTML.escape(order.billtoaddress3) %]</td>
        <td></td>
        <td align="right"></td>
        <td align="left">[% HTML.escape(order.shiptoaddress3) %]</td>
    </tr>
    <tr>
        <td align="right">City:</td>
        <td align="left">[% HTML.escape(order.billtocity) %]</td>
        <td></td>
        <td align="right">City:</td>
        <td align="left">[% HTML.escape(order.shiptocity) %]</td>
    </tr>
    <tr>
        <td align="right">State/Province:</td>
        <td align="left">[% HTML.escape(order.billtostate) %]</td>
        <td></td>
        <td align="right">State/Province:</td>
        <td align="left">[% HTML.escape(order.shiptostate) %]</td>
    </tr>
    <tr>
        <td align="right">Zip/Postal Code:</td>
        <td align="left">[% HTML.escape(order.billtozip) %]</td>
        <td></td>
        <td align="right">Zip/Postal Code:</td>
        <td align="left">[% HTML.escape(order.shiptozip) %]</td>
    </tr>
    <tr>
        <td align="right">Country:</td>
        <td align="left">[% HTML.escape(order.billtocountry) %]</td>
        <td></td>
        <td align="right">Country:</td>
        <td align="left">[% HTML.escape(order.shiptocountry) %]</td>
    </tr>
    <tr>
        <td align="right">Day Phone:</td>
        <td align="left">[% HTML.escape(order.billtodayphone) %]</td>
        <td></td>
        <td align="right">Day Phone:</td>
        <td align="left">[% HTML.escape(order.shiptodayphone) %]</td>
    </tr>
    <tr>
        <td align="right">Night Phone:</td>
        <td align="left">[% HTML.escape(order.billtonightphone) %]</td>
        <td></td>
        <td align="right">Night Phone:</td>
        <td align="left">[% HTML.escape(order.shiptonightphone) %]</td>
    </tr>
    <tr>
        <td align="right">Fax:</td>
        <td align="left">[% HTML.escape(order.billtofax) %]</td>
        <td></td>
        <td align="right">Fax:</td>
        <td align="left">[% HTML.escape(order.shiptofax) %]</td>
    </tr>
    <tr>
        <td align="right">Email:</td>
        <td align="left">[% HTML.escape(order.billtoemail) %]</td>
        <td></td>
        <td align="right">Email:</td>
        <td align="left">[% HTML.escape(order.shiptoemail) %]</td>
    </tr>
    <tr>
        <td colspan="5" height="5">&nbsp;</td>
    </tr>
    <tr>
        <td align="right" valign="top">Comments:</td>
        <td colspan="4" valign="top">[% HTML.escape(order.comments) %]</td>
    </tr>
    <tr>
        <td colspan="5" height="5">&nbsp;</td>
    </tr>
    <tr>
        <td colspan="5">
            <table border="0" cellpadding="3" cellspacing="5" width="100%">
                <tr>
                    <th align="left">SKU</th>
                    <th align="left">Description</th>
                    <th align="right">Price</th>
                    <th align="center">Quantity</th>
                    <th align="right">Total</th>
                </tr>
            [% FOREACH item = order.items %]
                <tr>
                        <td align="left">[% HTML.escape(item.sku) %]</td>
                        <td align="left">[% HTML.escape(item.description) %]</td>
                        <td align="right">[% HTML.escape(item.price.as_string('FMT_SYMBOL')) %]</td>
                        <td align="center">[% HTML.escape(item.quantity) %]</td>
                        <td align="right">[% HTML.escape(item.total.as_string('FMT_SYMBOL')) %]</td>
                </tr>
            [% END %]
                <tr>
                        <td align="right" colspan="4">Subtotal:</td>
                        <td align="right">[% HTML.escape(order.subtotal.as_string('FMT_SYMBOL')) %]</td>
                </tr>
                <tr>
                        <td align="right" colspan="4">Tax:</td>
                        <td align="right">[% HTML.escape(order.tax.as_string('FMT_SYMBOL')) %]</td>
                </tr>
                <tr>
                        <td align="right" colspan="4">Shipping:</td>
                        <td align="right">[% HTML.escape(order.shipping.as_string('FMT_SYMBOL')) %]</td>
                </tr>
                <tr>
                        <td align="right" colspan="4">Handling:</td>
                        <td align="right">[% HTML.escape(order.handling.as_string('FMT_SYMBOL')) %]</td>
                </tr>
                <tr>
                        <td align="right" colspan="4">Total:</td>
                        <td align="right">[% HTML.escape(order.total.as_string('FMT_SYMBOL')) %]</td>
                </tr>
            </table>
        </td>
    </td>
</table>
__errors__
[% TAGS [- -] -%]
[% IF errors %]
	<ul class="errors">
	[% FOREACH error IN errors %]
		<li>[% HTML.escape(error) %]</li>
	[% END %]
	</ul>
[% END %]
__messages__
[% action %]/view:
  id:
    REGEX: The id field is in the wrong format.
[% action %]/billing:
  billtofirstname:
    NOT_BLANK: The bill to first name field cannot be blank.
  billtolastname:
    NOT_BLANK: The bill to last name field cannot be blank.
  billtoaddress1:
    NOT_BLANK: The bill to address line 1 field cannot be blank.
  billtocity:
    NOT_BLANK: The bill to city field cannot be blank.
  billtostate:
    NOT_BLANK: The bill to state field cannot be blank.
  billtozip:
    NOT_BLANK: The bill to zip/postal code field cannot be blank.
  billtocountry:
    NOT_BLANK: The bill to country field cannot be blank.
  billtoemail:
    NOT_BLANK: The bill to email address field cannot be blank.
  shiptofirstname:
    NOT_BLANK: The ship to first name field cannot be blank.
  shiptolastname:
    NOT_BLANK: The ship to last name field cannot be blank.
  shiptoaddress1:
    NOT_BLANK: The ship to address line 1 field cannot be blank.
  shiptocity:
    NOT_BLANK: The ship to city field cannot be blank.
  shiptostate:
    NOT_BLANK: The ship to state field cannot be blank.
  shiptozip:
    NOT_BLANK: The ship to zip/postal code field cannot be blank.
  shiptocountry:
    NOT_BLANK: The ship to country field cannot be blank.
  shiptoemail:
    NOT_BLANK: The ship to email field cannot be blank.
[% action %]/payment:
  ccname:
    NOT_BLANK: The credit card name field is required.
  cctype:
    NOT_BLANK: The credit card type field is required.
  ccn:
    NOT_BLANK: The credit card number is required.
    LENGTH: The credit card number must be between 12 to 16 digits.
    UINT: The credit cart number must contain numbers only.
  ccm:
    NOT_BLANK: The credit card expiration month field is required.
    BETWEEN: The credot card month must be between 1 and 12.
  ccy:
    NOT_BLANK: The credit card expiration year is required.
    LENGTH: The credit card expiration year must be 2 digits long.
    UINT: The credit cart expiration year must contain numbers only.
  ccvn:
    NOT_BLANK: The credit card verification number is required.
    LENGTH: The credit card verification number must be 3 to 4 digits long.
    UINT: The credit cart verification number must contain numbers only.
__profiles__
[% action %]/view:
  - id
  -
    -
      - REGEX
      - !!perl/regexp (?i-xsm:^[a-f0-9]{8}-([a-f0-9]{4}-){3}[a-f0-9]{12}$)
[% action %]/billing:
  - billtofirstname
  - [ ['NOT_BLANK'], ['LENGTH', 1, 25] ]
  - billtolastname
  - [ ['NOT_BLANK'], ['LENGTH', 1, 25] ]
  - billtoaddress1
  - [ ['NOT_BLANK'], ['LENGTH', 1, 50] ]
  - billtocity
  - [ ['NOT_BLANK'], ['LENGTH', 1, 25] ]
  - billtostate
  - [ ['NOT_BLANK'], ['LENGTH', 1, 25] ]
  - billtozip
  - [ ['NOT_BLANK'], ['LENGTH', 1, 10] ]
  - billtocountry
  -  [ ['NOT_BLANK'], ['LENGTH', 1, 25] ]
  - billtoemail
  - [ ['NOT_BLANK'], ['LENGTH', 1, 50] ]
  - shiptofirstname
  - [ ['NOT_BLANK'], ['LENGTH', 1, 25] ]
  - shiptolastname
  - [ ['NOT_BLANK'], ['LENGTH', 1, 25] ]
  - shiptoaddress1
  - [ ['NOT_BLANK'], ['LENGTH', 1, 50] ]
  - shiptocity
  - [ ['NOT_BLANK'], ['LENGTH', 1, 25] ]
  - shiptostate
  - [ ['NOT_BLANK'], ['LENGTH', 1, 25] ]
  - shiptozip
  - [ ['NOT_BLANK'], ['LENGTH', 1, 10] ]
  - shiptocountry
  -  [ ['NOT_BLANK'], ['LENGTH', 1, 25] ]
  - shiptoemail
  - [ ['NOT_BLANK'], ['LENGTH', 1, 50] ]
[% action %]/payment:
  - ccname
  - [ ['NOT_BLANK'] ]
  - cctype
  - [ ['NOT_BLANK'] ]
  - ccn
  - [ ['NOT_BLANK'], ['LENGTH', 12, 16], ['UINT'] ]
  - ccm
  - [ ['NOT_BLANK'], ['BETWEEN', 1, 12] ]
  - ccy
  - [ ['NOT_BLANK'], ['LENGTH', 2], ['UINT'] ]
  - ccvn
  - [ ['NOT_BLANK'], ['LENGTH', 3, 4], ['UINT'] ]
__END__
