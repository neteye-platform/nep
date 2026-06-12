<?php

namespace Icinga\Module\Nep\ProvidedHook\Director\PropertyModifier;

use Icinga\Module\Director\Hook\PropertyModifierHook;
use Icinga\Module\Director\Web\Form\QuickForm;
use InvalidArgumentException;

class PropertyModifierNxAssignToBucket extends PropertyModifierHook
{
    public function getName()
    {
        return '[NX] Assign String to Bucket';
    }

    /**
     * @param QuickForm $form
     * @throws \Zend_Form_Exception
     */
    public static function addSettingsFormFields(QuickForm $form)
    {
        // Partition Key property name
        $form->addElement('text', 'nob', [
            'label'       => $form->translate('Number of Buckets'),
            'required'    => true,
            'value'       => '3',
            'description' => $form->translate(
                'Number of Buckets to divide objects into'
            ),
        ]);
        $form->addElement('select', 'base_index', [
            'label'        => $form->translate('Begin counting from'),
            'required'     => true,
            'value'        => '0',
            'multiOptions' => $form->optionalEnum([
                '0'   => $form->translate(''),
                '1'   => $form->translate('1'),
            ]),
            'description' => $form->translate(
                'Count Bucket Number starting from 0 or 1'
            ),
        ]);
    }

     /**
     * @param obj $value
     * @return int
     *
     * @throws InvalidArgumentException
     */
    public function transform($value)
    {
        $numberOfBuckets = (int)($this->getSetting('nob', '3'));
        $bucketBaseIndex = (int)($this->getSetting('base_index', '0'));

        return $this->assignToBucket($value, $numberOfBuckets) + $bucketBaseIndex;
    }

    /**
     * @param obj $value        The object to assign (string, number or something that can become a string)
     * @param int $numBuckets   The total number of available Buckets (must be > 0)
     *
     * @return int  The Bucket index (0-based)
     *
     * @throws InvalidArgumentException If $numBuckets is less than 1
     */
    private function assignToBucket($value, $numberOfBuckets)
    {
        if ($numberOfBuckets < 1) {
            throw new InvalidArgumentException("Number of Buckets must be greater than zero.");
        }

        // Using XOR of two different hashes to have a better distribution
        $strObj = (string)$value;
        $primaryHash = crc32($strObj);
        $secondaryHash = hexdec(substr(hash('sha256', $strObj), 0, 8));
        $combinedHash = $primaryHash ^ $secondaryHash;

        // Apply modulus to get bucket index
        return $combinedHash % $numberOfBuckets;
    }
}
