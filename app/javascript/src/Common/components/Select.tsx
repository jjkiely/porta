import * as React from 'react'

import {
  FormGroup,
  Select as PF4Select,
  SelectOptionObject as PFSelectOptionObject,
  SelectVariant
} from '@patternfly/react-core'
import { Spinner } from 'Common'
import {
  toSelectOption,
  toSelectOptionObject,
  SelectOptionObject,
  handleOnFilter
} from 'utilities'

import type { Record } from 'utilities'

import './Select.scss'

type Props<T extends Record> = {
  item: T | null,
  items: T[],
  onSelect: (arg1: T | null) => void,
  label: React.ReactNode,
  ariaLabel?: string,
  fieldId: string,
  name: string,
  isClearable?: boolean,
  placeholderText?: string,
  hint?: React.ReactNode,
  isValid?: boolean,
  helperText?: string,
  helperTextInvalid?: string,
  isDisabled?: boolean,
  isLoading?: boolean,
  isRequired?: boolean
};

const Select = <T extends Record>(
  {
    item,
    items,
    onSelect,
    label,
    ariaLabel,
    fieldId,
    name,
    isClearable = true,
    placeholderText = '',
    hint,
    isValid = true,
    helperText,
    helperTextInvalid,
    isDisabled = false,
    isLoading = false,
    isRequired = false
  }: Props<T>
): React.ReactElement => {
  const [expanded, setExpanded] = React.useState(false)

  const handleSelect = (_e: any, option: string | PFSelectOptionObject) => {
    setExpanded(false)

    const selected = items.find(i => i.id.toString() === (option as SelectOptionObject).id)
    onSelect(selected || null)
  }

  const handleOnClear = () => {
    if (isClearable) {
      onSelect(null)
      setExpanded(false) // TODO: in PF4 this is done automatically. Remove this after upgrading.
    }
  }

  return (
    <FormGroup
      isRequired={isRequired}
      label={label}
      fieldId={fieldId}
      isValid={isValid}
      helperText={helperText}
      helperTextInvalid={helperTextInvalid}
    >
      {isLoading && <Spinner size="md" className="pf-u-ml-md" />}
      {item && <input type="hidden" name={name} value={item.id > -1 ? item.id : ''} />}
      <PF4Select
        id={fieldId}
        variant={SelectVariant.typeahead}
        placeholderText={placeholderText}
        selections={(item && toSelectOptionObject(item)) || undefined}
        onToggle={() => setExpanded(!expanded)}
        onSelect={handleSelect}
        isExpanded={expanded}
        onClear={handleOnClear}
        aria-label={ariaLabel}
        isDisabled={isDisabled}
        onFilter={handleOnFilter(items)}
        className={isClearable ? '' : 'pf-m-select__toggle-clear-hidden'}
      >
        {items.map(toSelectOption)}
      </PF4Select>
      {hint}
    </FormGroup>
  )
}

export { Select, Props }
