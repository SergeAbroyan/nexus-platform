output "budget_arns" {
  description = "ARNs of the created AWS Budgets."
  value       = module.budget.budget_arns
}
