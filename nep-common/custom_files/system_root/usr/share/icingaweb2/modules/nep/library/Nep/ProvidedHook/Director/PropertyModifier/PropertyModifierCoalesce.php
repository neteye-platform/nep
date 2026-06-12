<?php

namespace Icinga\Module\Nep\ProvidedHook\Director\PropertyModifier;

use Icinga\Module\Director\Hook\PropertyModifierHook;
use Icinga\Module\Director\Import\SyncUtils;
use Icinga\Module\Director\Web\Form\QuickForm;

class PropertyModifierCoalesce extends PropertyModifierHook
{
    public static function addSettingsFormFields(QuickForm $form)
    {
        $form->addElement('text', 'value', array(
            'label'       => $form->translate('Default value'),
            'required'    => true,
            'description' => $form->translate(
                'Text to return if property is null. It can be another property or a combination of them (works like modifier "Combine multiple properties").'
            )
        ));
    }

    public function getName()
    {
        return '[NX] Return property value or a default value';
    }

    public function requiresRow()
    {
        return true;
    }

    public function transform($value)
    {
        if ($value === null) {
                return SyncUtils::fillVariables($this->getSetting('value'), $this->getRow());
        }

        return $value;
    }
}