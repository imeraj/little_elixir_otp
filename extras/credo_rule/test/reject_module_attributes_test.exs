defmodule RejectModuleAttributesTest do
  use Credo.Test.Case

  alias CredoRule.CredoChecks.RejectModuleAttributes

  describe "when no custom params" do
    test "it should NOT report expected code" do
      """
      defmodule CredoSampleModule do
        @somedoc "This is somedoc"
      end
      """
      |> to_source_file()
      |> run_check(RejectModuleAttributes)
      |> refute_issues()
    end

    test "it should report code that includes rejected module attribute names" do
      """
      defmodule CredoSampleModule do
        @checkdoc "This is checkdoc"
      end
      """
      |> to_source_file()
      |> run_check(RejectModuleAttributes)
      |> assert_issue(fn issue ->
        assert issue.line_no == 2
        assert issue.message == "There should be no `@checkdoc` module_attributes"

      end)
    end
  end

  describe "with custom params" do
    test "it should NOT report code that includes default rejected module attribute names when a custom set of rejected names is provided" do
      """
      defmodule CredoSampleModule do
        @checkdoc "This is checkdoc"
      end
      """
      |> to_source_file()
      |> run_check(RejectModuleAttributes, reject: [:somedoc])
      |> refute_issues()
    end

    test "it should report expected code when a custom set of rejected names is provided" do
      """
      defmodule CredoSampleModule do
        @somedoc "This is somedoc"
      end
      """
      |> to_source_file()
      |> run_check(RejectModuleAttributes, reject: [:somedoc])
      |> assert_issue(fn issue ->
          assert issue.line_no == 2
          assert issue.message == "There should be no `@somedoc` module_attributes"

      end)
    end
  end
end
