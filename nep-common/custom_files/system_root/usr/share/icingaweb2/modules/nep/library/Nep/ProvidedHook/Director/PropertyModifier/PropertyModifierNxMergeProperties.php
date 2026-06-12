<?php

namespace Icinga\Module\Nep\ProvidedHook\Director\PropertyModifier;

use Icinga\Module\Director\Hook\PropertyModifierHook;
use Icinga\Module\Director\Import\SyncUtils;
use Icinga\Module\Director\Web\Form\QuickForm;

class PropertyModifierNxMergeProperties extends PropertyModifierHook
{
    /**
     * @param QuickForm $form
     * @throws \Zend_Form_Exception
     */
    public static function addSettingsFormFields(QuickForm $form)
    {
        $form->addElement('text', 'values_to_merge', [
            'label'       => $form->translate('Properties to merge'),
            'required'    => true,
            'description' => $form->translate(
                'List of Properties to merge into the Source Property. Separate multiple Properties with a comma ",". The value of each Property will be converted into an Array if it is not already an Array.'
            ),
        ]);

        $form->addElement('select', 'include_property_value', [
            'label'       => $form->translate('Include Source Property'),
            'required'    => false,
            'description' => $form->translate(
                'Determine whether the value of the Source Property should be included in the merged result. If enabled, the value of the Source Property will be merged together with the values of the Properties specified above.'
            ),
            'value'        => 'yes',
            'multiOptions' => $form->optionalEnum([
                'yes' => $form->translate('Yes'),
                'no' => $form->translate('No'),
            ])
        ]);

        $form->addElement('select', 'property_name_as_key', [
            'label'       => $form->translate('Use Property Name as Key'),
            'required'    => false,
            'description' => $form->translate(
                'When enabled, if a value to be merged is not an Array, it will be merged as an associative array with the property name as key and the property value as value. If disabled, non-array values will be merged as-is, which may lead to unexpected results if multiple non-array values are merged together.'
            ),
            'value'        => 'no',
            'multiOptions' => $form->optionalEnum([
                'yes' => $form->translate('Yes'),
                'no' => $form->translate('No'),
            ])
        ]);
    }

    public function getName()
    {
        return '[NX] Merge Properties into Single Object';
    }

    public function requiresRow()
    {
        return true;
    }

    protected function deepCopy($value)
    {
        return unserialize(serialize($value));
    }

    /**
     * Resolves a single property value from $row into an array suitable for merging.
     *
     * Returns null if the property does not exist in $row (caller should skip it).
     * Arrays are returned as-is. Objects are cast to arrays.
     * Scalar values are wrapped: if $usePropertyName is true, they become
     * [ propertyName => value ]; otherwise they become [ value ].
     *
     * @param string $property      The property name to look up in $row.
     * @param object|array $row     The source row data.
     * @param bool $usePropertyName Whether to key scalar values by property name.
     * @return array|null
     */
    protected function getPropertyValue($property, $row, $usePropertyName): ?array
    {
        // Retrieve the value using Director's utility, which handles nested paths
        $property_value = SyncUtils::getSpecificValue($row, $property);

        // Property not present in the row — signal the caller to skip it
        if ($property_value === null) {
            return null;
        }

        $return_value = null;

        if (is_array($property_value)) {
            // Already an array, use directly
            $return_value = $property_value;
        } elseif (is_object($property_value)) {
            // Cast stdClass / objects to an associative array
            $return_value = (array) $property_value;
        } elseif ($usePropertyName) {
            // If requested, wrap scalar as [ 'propertyName' => value ] to preserve the key
            $return_value = [ $property => $property_value ];
        } else {
            // Wrap scalar as a plain indexed array entry
            $return_value = [ $property_value ];
        }

        return $this->deepCopy($return_value);
    }

    public function transform($value)
    {
        // Read modifier settings
        $usePropertyName    = $this->getSetting('property_name_as_key')    === 'yes';
        $includeSourceValue = $this->getSetting('include_property_value')  === 'yes';

        // Initialize the return value, optionally starting with the source property value
        $returnValue = null;
        if ($includeSourceValue) {
            $returnValue = $this->getPropertyValue($this->getPropertyName(), $this->getRow(), $usePropertyName);
        }
        if ($returnValue === null) {
            $returnValue = [];  // Ensures no null value is used, to avoid errors using array_merge
        }

        $row = $this->getRow();

        // Parse the comma-separated list of property names to merge
        $valuesToMerge = array_map('trim', explode(',', $this->getSetting('values_to_merge')));

        foreach ($valuesToMerge as $property) {
            $value_to_merge = $this->getPropertyValue($property, $row, $usePropertyName);

            // Skip properties that are missing from the row
            if ($value_to_merge === null) {
                continue;
            }

            // Merge into the result; later properties overwrite existing keys
            $returnValue = array_merge($returnValue, $value_to_merge);
        }

        return $returnValue;
    }
}