import { loadStripe } from '@stripe/stripe-js'
import { Elements } from '@stripe/react-stripe-js'
import { createReactWrapper } from 'utilities'
import { StripeCardForm } from 'PaymentGateways'
import 'PaymentGateways/stripe/styles/stripe.scss'

type Props = {
  stripePublishableKey: string,
  setupIntentSecret: string,
  billingAddressDetails: {
    line1: string,
    line2: string,
    city: string,
    state: string,
    // eslint-disable-next-line camelcase
    postal_code: string,
    country: string
  },
  successUrl: string,
  isCreditCardStored: boolean
};

const StripeElementsForm: React.FunctionComponent<Props> = ({
  stripePublishableKey,
  setupIntentSecret,
  billingAddressDetails,
  successUrl,
  isCreditCardStored
}) => {
  const stripePromise = loadStripe(stripePublishableKey)

  return (
    <Elements stripe={stripePromise}>
      <StripeCardForm
        setupIntentSecret={setupIntentSecret}
        billingAddressDetails={billingAddressDetails}
        successUrl={successUrl}
        isCreditCardStored={isCreditCardStored}
      />
    </Elements>
  )
}

const StripeFormWrapper = (props: Props, containerId: string): void => createReactWrapper(<StripeElementsForm {...props} />, containerId)

export { StripeElementsForm, StripeFormWrapper, Props }
