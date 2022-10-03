import { ProductsUsedListCardWrapper } from 'BackendApis/components/ProductsUsedListCard'
import { safeFromJsonString } from 'utilities'
import { CompactListItem } from 'Common/components/CompactListCard'

const containerId = 'products-used-list-container'

document.addEventListener('DOMContentLoaded', () => {
  const container = document.getElementById(containerId)

  if (!container) {
    return
  }

  const { products } = container.dataset

  ProductsUsedListCardWrapper({
    products: safeFromJsonString<Array<CompactListItem>>(products) || []
  }, containerId)
})
