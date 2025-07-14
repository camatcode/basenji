#!/usr/bin/env elixir
alias Basenji.Comics.ClassifierReport

Mix.install([
  {:image, "~> 0.54.4"},
  {:vix, "~> 0.31.0"}
])

# Generate a new report with the updated classifier settings
IO.puts("=== GENERATING UPDATED CLASSIFIER REPORT ===")
IO.puts("Updated settings:")
IO.puts("- Final score threshold: 0.6 → 0.7")
IO.puts("- Criteria required: 5/6 → 6/6")
IO.puts("- Sample more pages (4-6 instead of 3)")
IO.puts("- Start from page 3 instead of page 2")
IO.puts("- Added comic feature detection")
IO.puts("")

case ClassifierReport.generate_report() do
  :ok ->
    IO.puts("✅ Updated report generated successfully!")
    IO.puts("Check updated_classifier_report.txt for results")

  {:error, reason} ->
    IO.puts("❌ Report generation failed: #{inspect(reason)}")
end
