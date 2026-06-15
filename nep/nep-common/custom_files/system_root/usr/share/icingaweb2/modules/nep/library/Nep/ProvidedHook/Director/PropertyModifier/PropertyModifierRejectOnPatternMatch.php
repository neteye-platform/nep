<?php

namespace Icinga\Module\Nep\ProvidedHook\Director\PropertyModifier;

use Icinga\Module\Director\Hook\PropertyModifierHook;
use Icinga\Module\Director\Import\SyncUtils;
use Icinga\Module\Director\Web\Form\QuickForm;

class PropertyModifierRejectOnPatternMatch extends PropertyModifierHook
{
    public static function addSettingsFormFields(QuickForm $form)
    {
        $form->addElement('text', 'pattern', array(
            'label'       => $form->translate('Pattern'),
            'required'    => true,
            'description' => $form->translate(
                'This pattern will be matched with the main selected one. If it matches exaclty, the row will be skipped.'
                . 'Please provide field names in pattern using format ${some_column} .'
            )
        ));
    }

    public function getName()
    {
        return '[NX] Reject the row if the property is the same as pattern';
    }

    public function requiresRow()
    {
        return true;
    }

    public function transform($value)
    {
	$pattern = SyncUtils::fillVariables($this->getSetting('pattern'), $this->getRow());
	if($value == $pattern){
		$this->rejectRow();
	}
	return $value;
    }
}
