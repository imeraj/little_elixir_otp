defmodule CredoRule.CredoChecks.RejectModuleAttributes do
  @moduledoc false

  use Credo.Check,
    base_priority: :high,
    category: :readability,
    param_defaults: [reject: [:checkdoc]],
    explanations: [
      check: """
      Look, sometimes the policies for names of module attributes change.
      We want to make sure that all module attributes adhere to the newest standards of ACME Corp.

      We do not want to discuss this policy, we just want to stop you from using the old
      module attributes :)
      """,
      params: [reject: "This check warns about module attributes with any of the given names."]
    ]

  def run(%SourceFile{} = source_file, params \\ []) do
    rejected_names = Params.get(params, :reject, __MODULE__)
    issue_meta = IssueMeta.for(source_file, params)

    Credo.Code.prewalk(source_file, &traverse(&1, &2, rejected_names, issue_meta))
    |> Enum.reverse()
  end

  defp traverse(
         {:@, _, [{name, meta, [_string]} | _]} = ast,
         issues,
         rejected_names,
         issue_meta
       ) do
    issues =
      if Enum.member?(rejected_names, name) do
        [issue_for(name, meta[:line], issue_meta) | issues]
      else
        issues
      end

    {ast, issues}
  end

  defp traverse(ast, issues, _rejected_names, _issue_meta) do
    {ast, issues}
  end

  defp issue_for(trigger, line_no, issue_meta) do
    format_issue(
      issue_meta,
      message: "There should be no `@#{trigger}` module_attributes",
      trigger: trigger,
      line_no: line_no
    )
  end
end
