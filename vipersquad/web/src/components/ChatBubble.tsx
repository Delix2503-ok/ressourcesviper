import React from 'react'
import cx from 'classnames'
import Message from '../types/message'

type Props = {
   messageData: Message
}

export default function ChatBubble({
   messageData
}: Props) {
   if (messageData.system) {
      return (
         <div className="flex flex-col items-center w-full my-2">
            <div className="w-full border border-primary/30 bg-primary/10 rounded-lg px-3 py-2">
               <p className="text-xs font-bold text-primary uppercase tracking-wider text-center">
                  {messageData.message}
               </p>
            </div>
         </div>
      )
   }

   return (
      <div className={cx("flex flex-col gap-2 w-full max-w-[29.6296vh]", {
         "items-end": messageData.me,
         "items-start": !messageData.me
      })}>
         <div className='flex flex-row gap-2 items-center'>
            {!messageData.me && <img className="w-8 h-8 rounded-full border-2 border-primary" src={messageData.image} alt="Jese image" />}
            <div className={cx('flex flex-col', {
               'items-end': messageData.me,
               'items-start': !messageData.me,

            })}>
               <p className="text-sm h-3 font-semibold text-gray-900 dark:text-white">{messageData.name}</p>
               <p className="text-xs font-normal text-gray-500 dark:text-gray-400 mt-1">{messageData.time}</p>
            </div>
            {messageData.me && <img className="w-8 h-8 rounded-full border-2 border-primary" src={messageData.image} alt="Jese image" />}
         </div>
         <div className={cx("flex flex-col w-full max-w-[30vh] xl:max-w-[40vh] leading-1.5 px-2 border-gray-200 bg-gray-900/[.4]", {
            "rounded-e-xl rounded-es-xl": !messageData.me,
            "rounded-s-xl rounded-se-xl": messageData.me
         })}>
            <div className="flex items-center space-x-2 rtl:space-x-reverse">
               <p className="text-sm xl:text-xl font-normal py-2.5 text-white/[.4]">{messageData.message}</p>
            </div>
         </div>
      </div>
   )
}