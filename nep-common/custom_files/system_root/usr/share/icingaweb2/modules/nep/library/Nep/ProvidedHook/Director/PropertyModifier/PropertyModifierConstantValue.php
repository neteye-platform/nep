<?php

namespace Icinga\Module\Nep\ProvidedHook\Director\PropertyModifier;

use Icinga\Module\Director\Hook\PropertyModifierHook;
use Icinga\Module\Director\Import\SyncUtils;
use Icinga\Module\Director\Web\Form\QuickForm;

class PropertyModifierConstantValue extends PropertyModifierHook
{
    public static function addSettingsFormFields(QuickForm $form)
    {
        $form->addElement('text', 'pattern', array(
            'label'       => $form->translate('Pattern'),
            'required'    => false,
            'description' => $form->translate(
                'This pattern will be evaluated, and variables like ${some_column}'
                . ' will be filled accordingly. A typical use-case is generating'
                . ' unique service identifiers via ${host}!${service} in case your'
                . ' data source doesn\'t allow you to ship such. The chosen "property"'
                . ' has no effect here and will be ignored.'
            )
        ));

    }

    public function getName()
    {
        return '[NX] Replace property with constant value';
    }

    public function requiresRow()
    {
        return true;
    }

    public function transform($value)
    {
        return SyncUtils::fillVariables($this->getSetting('pattern'), $this->getRow());
    }
}
