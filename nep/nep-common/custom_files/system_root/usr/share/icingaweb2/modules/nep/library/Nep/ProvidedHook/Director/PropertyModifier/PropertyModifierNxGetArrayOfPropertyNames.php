<?php

namespace Icinga\Module\Nep\ProvidedHook\Director\PropertyModifier;

use Icinga\Module\Director\Hook\PropertyModifierHook;
use Icinga\Module\Director\Web\Form\QuickForm;

class PropertyModifierNxGetArrayOfPropertyNames extends PropertyModifierHook
{
    public static function addSettingsFormFields(QuickForm $form)
    {
    }

    public function getName()
    {
        return '[NX] Get array of first-level properties';
    }

    public function hasArraySupport() {
        return true;
    }

    public function transform($value)
    {
        if (is_object($value)) {
            return array_keys(get_object_vars($value));
        }
        if (is_array($value)) {
            return array_keys($value);
        }

        return null;
    }
}
