/* Copyright (c) 2020 VMWare, Inc. All rights reserved. */
/* SPDX-License-Identifier: GPL-2.0 WITH Linux-syscall-note */

#pragma once

#include "bcc_sensor.h"

#include <functional>
#include <cb-memory>

namespace ebpf {
    class BPF;
}


namespace cb_endpoint {
namespace bpf_probe {
    class IBpfApi
    {
    public:
        using UPtr = std::unique_ptr<IBpfApi>;
        using EventCallbackFn = std::function<void(struct data *data)>;

        enum class ProbeType
        {
            Entry,
            Return,
            LookupEntry,
            LookupReturn,
            Tracepoint
        };

        virtual ~IBpfApi() = default;

        virtual bool Init(const std::string & bpf_program) = 0;

        virtual void Reset() = 0;

        virtual bool AttachProbe(
            const char * name,
            const char * callback,
            ProbeType     type) = 0;

        virtual bool RegisterEventCallback(EventCallbackFn callback) = 0;

        virtual int PollEvents(int timeout_ms = -1) = 0;

        const std::string &GetErrorMessage() const
        {
            return m_ErrorMessage;
        }

        static const char *TypeToString(uint8_t type)
        {
            const char *str = "unknown";
            switch (type)
            {// LCOV_EXCL_START
            case EVENT_PROCESS_EXEC_ARG: str = "PROCESS_EXEC_ARG"; break;
            case EVENT_PROCESS_EXEC_PATH: str = "PROCESS_EXEC_PATH"; break;
            case EVENT_PROCESS_EXEC_RESULT: str = "PROCESS_EXEC_RESULT"; break;
            case EVENT_PROCESS_EXIT: str = "PROCESS_EXIT"; break;
            case EVENT_PROCESS_CLONE: str = "PROCESS_CLONE"; break;
            case EVENT_FILE_READ: str = "FILE_READ"; break;
            case EVENT_FILE_WRITE: str = "FILE_WRITE"; break;
            case EVENT_FILE_CREATE: str = "FILE_CREATE"; break;
            case EVENT_FILE_PATH: str = "FILE_PATH"; break;
            case EVENT_FILE_MMAP: str = "FILE_MMAP"; break;
            case EVENT_FILE_TEST: str = "FILE_TEST"; break;
            case EVENT_NET_CONNECT_PRE: str = "NET_CONNECT_PRE"; break;
            case EVENT_NET_CONNECT_ACCEPT: str = "NET_CONNECT_ACCEPT"; break;
            case EVENT_NET_CONNECT_DNS_RESPONSE: str = "NET_CONNECT_DNS_RESPONSE"; break;
            case EVENT_NET_CONNECT_WEB_PROXY: str = "NET_CONNECT_WEB_PROXY"; break;
            case EVENT_FILE_DELETE: str = "FILE_DELETE"; break;
            case EVENT_FILE_CLOSE: str = "FILE_CLOSE"; break;
            case EVENT_FILE_OPEN: str = "FILE_OPEN"; break;
            default: break;
            }// LCOV_EXCL_END
            return str;
        }

        static const char *StateToString(uint8_t state)
        {
            const char *str = "unknown";
            switch (state)
            {// LCOV_EXCL_START
            case PP_NO_EXTRA_DATA: str = "NO_EXTRA_DATA"; break;
            case PP_ENTRY_POINT: str = "ENTRY_POINT"; break;
            case PP_PATH_COMPONENT: str = "PATH_COMPONENT"; break;
            case PP_FINALIZED: str = "FINALIZED"; break;
            case PP_APPEND: str = "APPEND"; break;
            case PP_DEBUG: str = "DEBUG"; break;
            default: break;
            }// LCOV_EXCL_END
            return str;
        }

    protected:
        std::string                 m_ErrorMessage;
        EventCallbackFn             m_eventCallbackFn;
    };

    class BpfApi
        : public IBpfApi
    {
    public:
        BpfApi();
        virtual ~BpfApi();

        bool Init(const std::string & bpf_program) override;
        void Reset() override;

        bool AttachProbe(
            const char * name,
            const char * callback,
            ProbeType     type) override;

        bool RegisterEventCallback(EventCallbackFn callback) override;

        int PollEvents(int timeout_ms = -1) override;

        const std::string &GetErrorMessage() const
        {
            return m_ErrorMessage;
        }

    private:

        void LookupSyscallName(const char * name, std::string & syscall_name);

        // Returns True when kptr_restrict value was obtained
        bool GetKptrRestrict(long &kptr_restrict_value);

        void SetKptrRestrict(long value);

        void LowerKptrRestrict();

        void RaiseKptrRestrict();

        void CleanBuildDir();

        static void on_perf_submit(void *cb_cookie, void *data, int data_size);

        std::unique_ptr<ebpf::BPF>  m_BPF;
        const std::string           m_kptr_restrict_path;
        bool                        m_bracket_kptr_restrict;
        bool                        m_first_syscall_lookup;
        long                        m_kptr_restrict_orig;
    };
}
}
