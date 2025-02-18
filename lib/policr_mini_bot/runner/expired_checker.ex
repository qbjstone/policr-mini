defmodule PolicrMiniBot.Runner.ExpiredChecker do
  @moduledoc false

  alias PolicrMini.Schema.Verification
  alias PolicrMini.{Chats, VerificationBusiness}

  require Logger
  require PolicrMiniBot.Helper

  import PolicrMiniBot.Helper

  @spec run :: :ok

  @doc """
  修正所有过期的等待验证。
  """
  def run do
    # 获取所有处于等待状态的验证
    verifications = VerificationBusiness.find_all_waiting_verifications()
    # 计算已经过期的验证
    verifications =
      Enum.filter(verifications, fn v ->
        remaining_seconds = DateTime.diff(DateTime.utc_now(), v.inserted_at)
        remaining_seconds - (v.seconds + 30) > 0
      end)

    # 修正状态
    # TODO: 待优化：在同一个事物中更新所有验证记录
    Enum.each(verifications, fn verification ->
      # 自增统计数据（其它）。
      async do
        Chats.increment_statistic(
          verification.chat_id,
          verification.target_user_language_code,
          :other
        )
      end

      VerificationBusiness.update(verification, %{status: :expired})
    end)

    log_auto_corrected(verifications)
  end

  @spec log_auto_corrected([Verification.t()]) :: :ok | :ignore
  defp log_auto_corrected([v]) do
    Logger.warning(
      "Auto-corrected 1 verification: #{inspect(id: v.id, chat_id: v.chat_id, user_id: v.target_user_id)}"
    )

    :ok
  end

  defp log_auto_corrected([]) do
    :ignore
  end

  defp log_auto_corrected(vs) do
    Logger.warning("Auto-corrected #{length(vs)} verifications")

    :ok
  end
end
