import { ProductSelect } from 'NewApplication/components/ProductSelect'
import { mount } from 'enzyme'

import type { Props } from 'NewApplication/components/ProductSelect'
import type { Product } from 'NewApplication/types'

const product: Product = {
  id: 0,
  name: 'The Product',
  systemName: 'the_product',
  updatedAt: '',
  appPlans: [],
  servicePlans: [],
  defaultServicePlan: null,
  defaultAppPlan: null
}
const products = [product]
const props: Props = {
  product,
  products,
  productsCount: products.length,
  onSelectProduct: jest.fn(),
  productsPath: '/products',
  isDisabled: undefined
}

it('should render', () => {
  const wrapper = mount(<ProductSelect {...props} />)
  expect(wrapper.exists()).toBe(true)
})
