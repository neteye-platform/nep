<?php

namespace Icinga\Module\Nep\ProvidedHook\Director\PropertyModifier;

use Icinga\Module\Director\Hook\PropertyModifierHook;
use Icinga\Module\Director\Web\Form\QuickForm;

class PropertyModifierCopy extends PropertyModifierHook
{
    public static function addSettingsFormFields(QuickForm $form)
    {
    }

    public function getName()
    {
        return '[NX] Return the property value as it is';
    }

    public function requiresRow()
    {
        return true;
    }

    public function transform($value)
    {
        return $value;
    }
}