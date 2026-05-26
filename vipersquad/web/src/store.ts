import { configureStore } from '@reduxjs/toolkit'
import localeSlice from './slices/localeSlice'
import globalSlice from './slices/globalSlice'

export const store = configureStore({
  reducer: {
    localeSlice,
    globalSlice,
  },
})

export type RootState = ReturnType<typeof store.getState>
export type AppDispatch = typeof store.dispatch