import React from 'react';
import ReactDOM from 'react-dom/client';
import App from './components/App';
import './index.css';
import { Provider, useSelector, useDispatch } from "react-redux";
import { store, RootState } from './store';
import { VisibilityProvider } from './providers/VisibilityProvider';


ReactDOM.createRoot(document.getElementById('root')!).render(
  <React.StrictMode>
    <Provider store={store}>
        <App />
    </Provider>
  </React.StrictMode>,
);
