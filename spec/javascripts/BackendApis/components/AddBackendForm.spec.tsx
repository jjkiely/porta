import React from 'react'
import { act } from 'react-dom/test-utils'
import { mount, ReactWrapper } from 'enzyme'

import { AddBackendForm, Props } from 'BackendApis/components/AddBackendForm'
import { BackendSelect } from 'BackendApis/components/BackendSelect'
import { PathInput } from 'BackendApis/components/PathInput'
import { NewBackendModal } from 'BackendApis/components/NewBackendModal'
import { bool } from 'prop-types'

const backend = { id: 0, name: 'backend', privateEndpoint: 'example.org', systemName: 'backend' } as const
const backendsPath = '/backends'
const defaultProps = {
  backend: null,
  backends: [backend],
  inlineErrors: null,
  url: '',
  backendsPath
}

const mountWrapper = (props: Partial<Props> = {}) => mount(<AddBackendForm {...{ ...defaultProps, ...props }} />)

afterEach(() => {
  jest.resetAllMocks()
})

it('should render itself', () => {
  const wrapper = mountWrapper()
  expect(wrapper.exists()).toBe(true)
})

it('should enable submit button only when form is filled', () => {
  const wrapper = mountWrapper()
  const isSubmitButtonDisabled = (wrapper: ReactWrapper): boolean => Boolean(wrapper.find('button[data-testid="addBackend-buttonSubmit"]').prop('disabled'))
  expect(isSubmitButtonDisabled(wrapper)).toBe(true)

  act(() => {
    wrapper.find(BackendSelect).props().onSelect(null)
    wrapper.find(PathInput).props().setPath('')
  })
  wrapper.update()
  expect(isSubmitButtonDisabled(wrapper)).toBe(true)

  act(() => {
    wrapper.find(BackendSelect).props().onSelect(backend)
    wrapper.find(PathInput).props().setPath('')
  })
  wrapper.update()
  expect(isSubmitButtonDisabled(wrapper)).toBe(false)

  act(() => {
    wrapper.find(BackendSelect).props().onSelect(null)
    wrapper.find(PathInput).props().setPath('/path')
  })
  wrapper.update()
  expect(isSubmitButtonDisabled(wrapper)).toBe(true)

  act(() => {
    wrapper.find(BackendSelect).props().onSelect(backend)
    wrapper.find(PathInput).props().setPath('/path')
  })
  wrapper.update()
  expect(isSubmitButtonDisabled(wrapper)).toBe(false)
})

it('should open/close a modal with a form to create a new backend', () => {
  const wrapper = mountWrapper()
  expect(wrapper.find(NewBackendModal).prop('isOpen')).toBe(false)

  act(() => { wrapper.find('button[data-testid="newBackendCreateBackend-buttonLink"]').simulate('click') })
  wrapper.update()
  expect(wrapper.find(NewBackendModal).prop('isOpen')).toBe(true)

  act(() => { wrapper.find('button[data-testid="cancel"]').simulate('click') })
  wrapper.update()
  expect(wrapper.find(NewBackendModal).prop('isOpen')).toBe(false)
})

it('should select the new backend when created', () => {
  const wrapper = mountWrapper()
  const newBackend = { id: 1, name: 'New backend', privateEndpoint: 'example.org', systemName: 'new_backend' } as const

  act(() => { wrapper.find(NewBackendModal).props().onCreateBackend(newBackend) })

  wrapper.update()
  expect(wrapper.find(BackendSelect).prop('backend')).toBe(newBackend)
})

it('should be able to have a default backend selected', () => {
  const wrapper = mountWrapper({ backend })

  expect(wrapper.find('BackendSelect .pf-c-select__toggle-typeahead').props().value).toEqual(backend.name)
})

it('should be able to show inline errors', () => {
  const inlineErrors = {
    backend_api_id: ['invalid backend'],
    path: ['invalid path']
  }
  const wrapper = mountWrapper({ inlineErrors })

  expect(wrapper.find('BackendSelect .pf-c-form__helper-text.pf-m-error').text()).toEqual('invalid backend')
  expect(wrapper.find('PathInput .pf-c-form__helper-text.pf-m-error').text()).toEqual('invalid path')
})
