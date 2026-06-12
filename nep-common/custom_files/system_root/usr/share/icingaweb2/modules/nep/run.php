<?php

use Icinga\Module\Nep\ProvidedHook\Director\PropertyModifier\PropertyModifierCoalesce;
use Icinga\Module\Nep\ProvidedHook\Director\PropertyModifier\PropertyModifierCompareFieldContentAgainstPattern;
use Icinga\Module\Nep\ProvidedHook\Director\PropertyModifier\PropertyModifierConstantValue;
use Icinga\Module\Nep\ProvidedHook\Director\PropertyModifier\PropertyModifierCopy;
use Icinga\Module\Nep\ProvidedHook\Director\PropertyModifier\PropertyModifierNxArrayElementByPosition;
use Icinga\Module\Nep\ProvidedHook\Director\PropertyModifier\PropertyModifierNxAssignToBucket;
use Icinga\Module\Nep\ProvidedHook\Director\PropertyModifier\PropertyModifierNxGetArrayOfPropertyNames;
use Icinga\Module\Nep\ProvidedHook\Director\PropertyModifier\PropertyModifierNxMap;
use Icinga\Module\Nep\ProvidedHook\Director\PropertyModifier\PropertyModifierNxMergeProperties;
use Icinga\Module\Nep\ProvidedHook\Director\PropertyModifier\PropertyModifierNxPartitionArrayByKey;
use Icinga\Module\Nep\ProvidedHook\Director\PropertyModifier\PropertyModifierNxSetDictionaryAttribute;
use Icinga\Module\Nep\ProvidedHook\Director\PropertyModifier\PropertyModifierRejectOnPatternMatch;

$this->provideHook('director/PropertyModifier', PropertyModifierCoalesce::class);
$this->provideHook('director/PropertyModifier', PropertyModifierCompareFieldContentAgainstPattern::class);
$this->provideHook('director/PropertyModifier', PropertyModifierConstantValue::class);
$this->provideHook('director/PropertyModifier', PropertyModifierCopy::class);
$this->provideHook('director/PropertyModifier', PropertyModifierNxArrayElementByPosition::class);
$this->provideHook('director/PropertyModifier', PropertyModifierNxAssignToBucket::class);
$this->provideHook('director/PropertyModifier', PropertyModifierNxGetArrayOfPropertyNames::class);
$this->provideHook('director/PropertyModifier', PropertyModifierNxMap::class);
$this->provideHook('director/PropertyModifier', PropertyModifierNxMergeProperties::class);
$this->provideHook('director/PropertyModifier', PropertyModifierNxPartitionArrayByKey::class);
$this->provideHook('director/PropertyModifier', PropertyModifierNxSetDictionaryAttribute::class);
$this->provideHook('director/PropertyModifier', PropertyModifierRejectOnPatternMatch::class);