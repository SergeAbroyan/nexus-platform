output "queue_arn" {
  description = "ARN of the primary job queue."
  value       = module.queue.queue_arn
}

output "queue_url" {
  description = "URL used by the API and worker to access the primary job queue."
  value       = module.queue.queue_url
}

output "queue_name" {
  description = "Name of the primary job queue."
  value       = module.queue.queue_name
}

output "dead_letter_queue_arn" {
  description = "ARN of the queue that stores repeatedly failed messages."
  value       = module.queue.dead_letter_queue_arn
}

output "dead_letter_queue_url" {
  description = "URL of the queue that stores repeatedly failed messages."
  value       = module.queue.dead_letter_queue_url
}

output "dead_letter_queue_name" {
  description = "Name of the queue that stores repeatedly failed messages."
  value       = module.queue.dead_letter_queue_name
}
