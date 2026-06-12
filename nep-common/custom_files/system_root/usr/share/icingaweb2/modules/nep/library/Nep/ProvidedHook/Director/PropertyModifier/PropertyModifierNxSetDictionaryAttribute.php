<?php

namespace Icinga\Module\Nep\ProvidedHook\Director\PropertyModifier;

use Icinga\Module\Director\Hook\PropertyModifierHook;
use Icinga\Module\Director\Import\SyncUtils;
use Icinga\Module\Director\Web\Form\QuickForm;
use InvalidArgumentException;

/**
 * Property modifier that sets or modifies attributes on nested dictionaries (objects or arrays).
 *
 * This modifier recursively traverses through objects and arrays to find a target attribute
 * at a specified nesting level and replaces its value with a configured replacement value.
 * Empty strings are converted to null values. The modifier can be configured to either
 * continue or fail when encountering primitive (non-object, non-array) values at first level.
 */
class PropertyModifierNxSetDictionaryAttribute extends PropertyModifierHook
{
    /** @var string The name of the attribute to find and replace */
    private $attributeName;

    /** @var int|null The nesting level at which the attribute should be located (null = any level) */
    private $nestingLevel;

    /** @var string Behavior when encountering primitive types: 'continue' or 'fail' */
    private $onPrimitiveTypes;

    /** @var mixed The replacement value to assign to the matched attribute */
    private $replacementValue;

    /**
     * Configure form fields for this property modifier.
     *
     * Adds form elements for:
     * - attribute_name: The target attribute to find and replace
     * - attribute_value: The replacement value (empty string becomes null)
     * - nesting_level: Optional constraint for attribute location depth (0-based)
     * - on_primitive_types: Action when encountering primitive values
     *
     * @param QuickForm $form The form to add elements to
     * @throws \Zend_Form_Exception If a form element cannot be added
     */
    public static function addSettingsFormFields(QuickForm $form)
    {
        // Field for specifying the attribute name to find and replace
        $form->addElement('text', 'attribute_name', [
            'label'       => $form->translate('Attribute name'),
            'required'    => true,
            'description' => $form->translate(
                'Name of the attribute to set on the Source Property.'
            ),
        ]);

        // Field for specifying the replacement value (empty string becomes null)
        $form->addElement('text', 'attribute_value', [
            'label'       => $form->translate('New Attribute Value'),
            'required'    => false,
            'description' => $form->translate(
                'Value to assign to the Attribute when found. Empty string will be converted to null, this removing the Attribute.'
            ),
        ]);

        // Optional field to constrain the search to a specific nesting depth
        $form->addElement('text', 'nesting_level', [
            'label'       => $form->translate('Expected Nesting Level'),
            'required'    => false,
            'description' => $form->translate(
                'Expected nesting level of the Attribute on the Source Property. Begins from 0 (root level). Do not accept negative values. If no value is specified, Attribute will be searched everywhere in the Object.'
            ),
        ]);

        // Field to configure behavior when encountering primitive (non-traversable) values
        $form->addElement('select', 'on_primitive_types', [
            'label'       => $form->translate('When Property is a Primitive Type'),
            'required'    => true,
            'description' => $form->translate(
                'What should happen when the Property Value is not an Object nor an Array. Null is considered an empty value and so will be skipped.'
            ),
            'value'        => 'continue',
            'multiOptions' => $form->optionalEnum([
                'continue' => $form->translate('Continue'),
                'fail' => $form->translate('Let the whole Import Run fail'),
            ])
        ]);
    }

    /**
     * Get the human-readable name for this property modifier.
     *
     * @return string
     */
    public function getName()
    {
        return '[NX] Set Dictionary Attribute';
    }

    /**
     * Indicate that this modifier supports array values.
     *
     * @return bool
     */
    public function hasArraySupport()
    {
        return true;
    }

    /**
     * Parse and validate the nesting level setting.
     *
     * Converts string representations of non-negative integers to int type.
     * Returns null if the setting is empty or null (indicates search at any level).
     *
     * @param mixed $nestingLevel The raw nesting level value
     * @return int|null The parsed nesting level, or null for any level
     * @throws InvalidArgumentException If nesting level is negative or not a valid integer
     */
    protected function parseNestingLevel($nestingLevel)
    {
        // Return null if nesting level is empty or not specified (search at any level)
        if ($nestingLevel === null || $nestingLevel === '') {
            return null;
        }

        // Validate integer values
        if (is_int($nestingLevel)) {
            if ($nestingLevel < 0) {
                throw new InvalidArgumentException('Nesting level must not be negative');
            }
            return $nestingLevel;
        }

        // Convert string numeric values to integer
        if (is_string($nestingLevel) && ctype_digit($nestingLevel)) {
            return (int) $nestingLevel;
        }

        // Reject invalid formats
        throw new InvalidArgumentException(sprintf(
            'Invalid nesting level "%s". Expected a non-negative integer',
            $nestingLevel
        ));
    }

    /**
     * Check if the current nesting level matches the target level.
     *
     * @param int|null $targetLevel The target nesting level (null = all levels)
     * @param int $currentLevel The current nesting level being traversed
     * @return bool True if we should replace at this level
     */
    protected function shouldReplaceAtLevel($targetLevel, $currentLevel)
    {
        return $targetLevel === null || $targetLevel === $currentLevel;
    }

    /**
     * Recursively traverse and modify nested structures (arrays and objects).
     *
     * For arrays: Recurses into each item, incrementing the nesting level.
     * For objects: Checks each attribute for a name match at the target level,
     * replaces if matched, then recurses into child values.
     * Other types are skipped.
     *
     * @param mixed &$value The value to traverse (passed by reference for modification)
     * @param int|null $targetLevel The target nesting level for attribute replacement
     * @param int $currentLevel The current depth in the nested structure
     */
    protected function applyValue(&$value, $targetLevel, $currentLevel)
    {
        // Process arrays: recurse into each element at the next nesting level
        if (is_array($value)) {
            foreach ($value as &$item) {
                $this->applyValue($item, $targetLevel, $currentLevel + 1);
            }
            unset($item);
        } elseif (is_object($value)) {
            // Process objects: check each property
            foreach ($value as $propertyName => &$propertyValue) {
                // Replace attribute if name matches and nesting level is correct
                if ($propertyName === $this->attributeName && $this->shouldReplaceAtLevel($targetLevel, $currentLevel)) {
                    if ($this->replacementValue === null) {
                        // Remove property if replacement value is null
                        unset($value->$propertyName);
                        continue;
                    }
                    // Replace property value
                    $propertyValue = $this->replacementValue;
                }
                // Recurse into property values
                $this->applyValue($propertyValue, $targetLevel, $currentLevel + 1);
            }
            unset($propertyValue);
        }
        // Primitive types are skipped (no recursion needed)
    }

    /**
     * Transform the input value by finding and replacing the configured attribute.
     *
     * Initializes instance variables from settings, validates nesting level,
     * and recursively applies the attribute replacement to the value.
     * Null input values are returned unchanged. Empty string replacement values
     * are converted to null. Primitive type values trigger the configured action.
     *
     * @param mixed $value The value to transform
     * @return mixed The transformed value
     * @throws InvalidArgumentException If nesting level is invalid
     * @throws InvalidArgumentException If a primitive value is encountered and on_primitive_types is 'fail'
     */
    public function transform($value)
    {
        // Initialize instance variables from form settings
        $this->attributeName = $this->getSetting('attribute_name');
        $this->nestingLevel = $this->getSetting('nesting_level');
        $this->onPrimitiveTypes = $this->getSetting('on_primitive_types');
        $this->replacementValue = $this->getSetting('attribute_value');

        // Null input is considered empty and returned unchanged
        if ($value === null) {
            // Consider null as an empty value and skip it
            return null;
        }

        // Parse and validate the nesting level setting
        $targetLevel = $this->parseNestingLevel($this->nestingLevel);

        // Convert empty string replacement value to null
        if ($this->replacementValue === '') {
            $this->replacementValue = null;
        }

        // Recursively apply attribute replacement to arrays and objects
        if (is_array($value) || is_object($value)) {
            $this->applyValue($value, $targetLevel, 0);
            return $value;
        }

        // Handle primitive values according to configuration
        if ($this->onPrimitiveTypes === 'fail') {
            throw new InvalidArgumentException(sprintf(
                'Primitive value for property "%s" cannot be traversed',
                $this->getPropertyName()
            ));
        }

        return $value;
    }
}