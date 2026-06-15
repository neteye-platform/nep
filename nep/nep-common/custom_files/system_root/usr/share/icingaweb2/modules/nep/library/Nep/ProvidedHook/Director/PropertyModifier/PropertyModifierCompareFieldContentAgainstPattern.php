<?php

namespace Icinga\Module\Nep\ProvidedHook\Director\PropertyModifier;

use Icinga\Module\Director\Hook\PropertyModifierHook;
use Icinga\Module\Director\Import\SyncUtils;
use Icinga\Module\Director\Web\Form\QuickForm;

class PropertyModifierCompareFieldContentAgainstPattern extends PropertyModifierHook
{
    public static function addSettingsFormFields(QuickForm $form)
    {
        $form->addElement('text', 'pattern', array(
            'label'       => $form->translate('Pattern'),
            'required'    => true,
            'description' => $form->translate(
                'This pattern will be matched with the main selected one. If it matches exaclty, the modifier fill return true.'
                . 'Please provide field names in pattern using format ${some_column} .'
            )
        ));
    }

    public function getName()
    {
        return '[NX] Compare field content to a specific pattern';
    }

    public function requiresRow()
    {
        return true;
    }

    public function transform($value)
    {
        $pattern = SyncUtils::fillVariables($this->getSetting('pattern'), $this->getRow());
        return ($value == $pattern);
    }
}
