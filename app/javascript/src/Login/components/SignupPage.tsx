import { LoginPage } from '@patternfly/react-core'

import { createReactWrapper } from 'utilities/createReactWrapper'
import brandImg from 'Login/assets/images/3scale_Logo_Reverse.png'
import PF4DownstreamBG from 'Login/assets/images/PF4DownstreamBG.svg'
import { FlashMessages } from 'Login/components/FlashMessages'
import { SignupForm } from 'Login/components/SignupForm'

import type { FunctionComponent } from 'react'
import type { SignupProps as Props } from 'Types'

const SignupPage: FunctionComponent<Props> = ({ user, name, path }) => (
  <LoginPage
    backgroundImgAlt="Red Hat 3scale API Management"
    backgroundImgSrc={PF4DownstreamBG}
    brandImgAlt="Red Hat 3scale API Management"
    brandImgSrc={brandImg}
    loginTitle={`Signup to ${String(name)}`}
  >
    {user.errors && <FlashMessages flashMessages={user.errors} />}
    <SignupForm path={path} user={user} />
  </LoginPage>
)

// eslint-disable-next-line react/jsx-props-no-spreading
const SignupPageWrapper = (props: Props, containerId: string): void => { createReactWrapper(<SignupPage {...props} />, containerId) }

export type { Props }
export { SignupPage, SignupPageWrapper }
