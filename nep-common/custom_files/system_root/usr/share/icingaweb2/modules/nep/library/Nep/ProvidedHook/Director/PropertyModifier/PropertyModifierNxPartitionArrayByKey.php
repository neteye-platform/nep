<?php

namespace Icinga\Module\Nep\ProvidedHook\Director\PropertyModifier;

use Icinga\Module\Director\Hook\PropertyModifierHook;
use Icinga\Module\Director\Web\Form\QuickForm;
use InvalidArgumentException;

/**
 * This modifier takes in an Array of Objects and will partition it into several
 * arrays based on a Key Property. The name of this Property should be provided as
 * parameter. Objects that have no value (empty string) or null value for the Key
 * Property will remain in the Source Array.
 *
 * Partitioned Arrays will be named after the value of Key Property. Optionally,
 * each Array Name can be prefixed with the name of the Source Property.
 *
 * Partitioned Arrays will be returned as Properties of a single Object.
 */
class PropertyModifierNxPartitionArrayByKey extends PropertyModifierHook
{
    public function getName(): string
    {
        return '[NX] Partition Array of Objects by Key';
    }

    public function hasArraySupport(): bool
    {
        return true;
    }

    /**
     * @param QuickForm $form
     * @throws \Zend_Form_Exception
     */
    public static function addSettingsFormFields(QuickForm $form)
    {
        // Partition Key property name
        $form->addElement('text', 'partition_key', [
            'label'       => $form->translate('Partition Key'),
            'required'    => true,
            'description' => $form->translate(
                'Name of the Object Property used to partition the Array. It should be (or can converted into) a string'
            ),
        ]);
        // Whether to prefix each Partitioned Array Key with Source Property Name or not
        $form->addElement('select', 'partition_array_prefix', [
            'label'       => $form->translate('Partitioned Array Names'),
            'required'    => true,
            'description' => $form->translate(
                'Uses Property Name as Prefix for each Array Partition that is created. Glue character is "_"'
            ),
            'value' => 'key_and_property',
            'multiOptions' => [
                'key_and_property' => $form->translate('Prefix Partition key with Property Name'),
                'key_only'         => $form->translate('Use Partition key Value only'),
            ],
        ]);
        $form->addElement('select', 'sanitize', array(
            'label'       => $form->translate('Sanitize Paritioned Array Names'),
            'required'    => true,
            'description' => $form->translate(
                'Name of each Partitioned Array will be sanitized, so it can be safely ised as Customvar Name (replace "-" with "_", then lowercased)'
            ),
            'value' => 'n',
            'multiOptions' => array(
                'y' => $form->translate('Yes'),
                'n' => $form->translate('No'),
            ),
        ));
        $form->addElement('select', 'on_failure', [
            'label' => 'On failure',
            'description' => $form->translate('What should we do in case we are unable to perform the operation?'),
            'multiOptions' => $form->optionalEnum([
                'null' => $form->translate('Set no value (null)'),
                'keep' => $form->translate('Keep the Array as is'),
                'fail' => $form->translate('Let the whole import run fail'),
            ]),
            'required' => true,
        ]);
    }

    /**
     * @throws InvalidArgumentException
     */
    public function transform($value)
    {
        if (null === $value) {
            return null;
        }

        try {
            return $this->applyTransformation($value);
        } catch (InvalidArgumentException $e) {
            switch ($this->getSetting('on_failure')) {
                case 'null':
                    return null;
                case 'keep':
                    return $value;
                case 'fail':
                default:
                    throw $e;
            }
        }
    }

    protected function applyTransformation($value): array
    {
        if (!is_array($value)) {
            throw new InvalidArgumentException('Expected an Array, got ' . gettype($value));
        }

        $partitions = [];
        $leftovers = [];
        $keyProperty = $this->getSetting('partition_key');
        $partitionNamePrefix = $this->getPartitionNamePrefix();
        $sourcePropertyName = $this->getPropertyName();

        foreach ($value as $sourceElement) {
            if (!is_object($sourceElement)) {
                throw new InvalidArgumentException(
                    'Source Array Element expected to be an Object, but got ' . gettype($sourceElement)
                );
            }

            // Place the element in our leftovers and skip it in case it is missing the partition key
            if (!property_exists($sourceElement, $keyProperty)) {
                $leftovers[] = $sourceElement;
                continue;
            }
            $partitionName = $partitionNamePrefix . self::requireString($sourceElement->$keyProperty);
            if ($partitionName === $sourcePropertyName) {
                throw new InvalidArgumentException(sprintf(
                    'Name build for Partition Name using Partition Key value "%s" has the same value as'
                    . ' the Property Name. This would lead to data loss',
                    $partitionName
                ));
            }

            if ($this->getSetting('sanitize', 'n') === 'y') {
                $partitionName = $this->sanitize_as_customvar_name($partitionName);
            }

            // No valid key? Skip.
            if ($partitionName === $partitionNamePrefix) {
                $leftovers[] = $sourceElement;
                continue;
            }

            if (array_key_exists($partitionName, $partitions)) {
                $partitions[$partitionName][] = $sourceElement;
            } else {
                $partitions[$partitionName] = [$sourceElement];
            }
        }

        // Add leftovers to the resulting Object (if there are any)
        if (!empty($leftovers)) {
            $propertyName = $this->getPropertyName();
            $partitions[$propertyName] = $leftovers;
        }

        return $partitions;
    }

    private function sanitize_as_customvar_name($value): string
    {
        if (is_string($value)) {
            return strtolower(str_replace('-', '_', $value));
        }

        return $value;
    }

    /**
     * Used to test if a value is a string or can become one.
     * If not, an exception is raised.
     *
     * @throws InvalidArgumentException
     */
    private function requireString($value): string
    {
        if (is_string($value)) {
            return $value;
        }

        if (is_object($value) && method_exists($value, '__toString')) {
            return (string) ($value);
        }

        throw new InvalidArgumentException('Expected String-like Partition Key, got ' . gettype($value));
    }

    /**
     * Returns a string that can be used as Prefix for a
     * Partition Array Name; if no Prefix should be used,
     * returns '' (an empty string).
     */
    private function getPartitionNamePrefix(): string
    {
        $glue = '_';
        if ($this->getSetting('partition_array_prefix') === 'key_and_property') {
            return $this->getPropertyName() . $glue;
        }

        return '';
    }
}
